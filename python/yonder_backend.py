import json
import sys

from jamdict import Jamdict
from sudachipy import dictionary, tokenizer


tokenizer_obj = dictionary.Dictionary().create()
jam = Jamdict()


# Translate katakana to hiragana
def katakana_to_hiragana(text: str) -> str:
    result = []

    for c in text:
        code = ord(c)

        if 0x30A1 <= code <= 0x30F6:
            # Question: code in 0x30A1 to 0x30F6 is katakana?
            # Yes
            # Question: what is 0x60?
            # katakana a - hiragana a = 0x60
            result.append(chr(code - 0x60))
        else:
            result.append(c)

    return "".join(result)


# Summary: find the morpheme pointed by cursor

# Return:  the morpheme pointed by cursor
def morpheme_at_cursor(text: str, cursor_byte: int):
    morphemes = tokenizer_obj.tokenize(
        text,
        tokenizer.Tokenizer.SplitMode.C,
    )

    byte_offset = 0

    for m in morphemes:
        surface = m.surface()

        start = byte_offset
        end = start + len(surface.encode("utf-8"))

        if start <= cursor_byte < end:
            return m

        byte_offset = end

    return None


# Summary: 
# 1. find morpheme pointed by cursor by calling morpheme_at_cursor()
# 2. lookup the term in jamdict

# Return:
#    return {
#        "query": surface,
#        "term": term,
#        "reading": reading,
#        "pos": list(target.part_of_speech()),
#        "entries": [
#            str(entry)
#            for entry in result.entries[:5]
#        ],
#        "sentence": text,
#    }


def analyse_at_cursor(text: str, cursor_byte: int) -> dict:
    target = morpheme_at_cursor(text, cursor_byte)

    if target is None:
        return {
            "query": None,
            "term": None,
            "entries": [],
            "error": "No morpheme under cursor",
        }

    surface = target.surface()
    term = target.dictionary_form()
    reading = katakana_to_hiragana(
        target.reading_form()
    )

    result = jam.lookup(term)

    return {
        "query": surface,
        "term": term,
        "reading": reading,
        "pos": list(target.part_of_speech()),
        "entries": [
            str(entry)
            for entry in result.entries[:5]
        ],
        "sentence": text,
    }

# parse a str into morphemes using tokenizer in SplitMode.C
# lookup the first morpheme with dict

# return {
#     "query": text,
#     "term": term,
#     "reading": reading,
#     "tokens": tokens,
#     "entries": entries,
# }


def analyse(text: str) -> dict:
    morphemes = tokenizer_obj.tokenize(
        text,
        tokenizer.Tokenizer.SplitMode.C,
    )
    # Question: what is SplitMode.C?
    # This controls how to split the text into morphemes. 
    # Mode A: splits the text into minimal morphemes.
    # Mode B: the regular mode.
    # Mode C: splits the text, reserving the special words, compound words
    # Question: what is morphemes? 
    # a basic semantic unit of Japanese text, like こんにちは
    # morphemes is a list of morpheme structure, like [mor("こんにちは"), ]
    tokens = []

    for m in morphemes:
        pos = m.part_of_speech()
        # 6 attributes of this morpheme

        tokens.append(
            {
                "surface": m.surface(),
                # surface is the surface form of the morpheme, the original text. 読んだ、食べました
                "dictionary_form": m.dictionary_form(),
                # dictionary_form is the dictionary form of the morpheme.読む、食べる 
                "reading": katakana_to_hiragana(m.reading_form()),
                # m.reading_form() returns katakana by default.
                "pos": list(pos),
            }
        )

    # 第一版：
    # 跳过助词、助动词、符号，找第一个有实义的词
    target = None

    ignored_pos = {
        "助詞",
        "助動詞",
        "補助記号",
        "空白",
    }

    for m in morphemes:
        if m.part_of_speech()[0] not in ignored_pos:
            target = m
            break

    if target is None and morphemes:
        target = morphemes[0]

    if target is None:
        return {
            "query": text,
            "tokens": [],
            "term": None,
            "reading": None,
            "entries": [],
        }

    term = target.dictionary_form()
    reading = katakana_to_hiragana(target.reading_form())

    result = jam.lookup(term)
    # get the result of the lookup, which is a list of explanations

    entries = [str(entry) for entry in result.entries[:5]]
    # get the first 5 entries

    return {
        "query": text,
        "term": term,
        "reading": reading,
        "tokens": tokens,
        "entries": entries,
    }


def main() -> None:
    command = sys.argv[1]

    if command == "lookup":
        result = analyse(sys.argv[2])

    elif command == "cursor":
        text = sys.argv[2]
        cursor_byte = int(sys.argv[3])

        result = analyse_at_cursor(
            text,
            cursor_byte,
        )

    else:
        result = {
            "error": f"unknown command: {command}"
        }

    print(
        json.dumps(
            result,
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
