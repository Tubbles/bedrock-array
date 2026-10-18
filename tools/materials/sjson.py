"""Reader for Bitsquid simplified JSON (SJSON), the form of the project's data files.

Standard library only, so it runs in Blender's bundled Python and the system Python alike.
"""

import re
from typing import Any, List, NamedTuple, Tuple


class SjsonError(Exception):
    """A parse error; the message names the line (1 based) and what was expected."""


class Token(NamedTuple):
    kind: str  # "punctuation", "string", "number", "identifier" or "end"
    value: Any
    line: int


PUNCTUATION = "{}[]=:,"
WHITESPACE = " \t\r\n"
IDENTIFIER_PATTERN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
NUMBER_PATTERN = re.compile(r"-?[0-9]+(\.[0-9]*)?([eE][+-]?[0-9]+)?")
SIMPLE_ESCAPES = {'"': '"', "\\": "\\", "/": "/", "b": "\b", "f": "\f", "n": "\n", "r": "\r", "t": "\t"}
LITERALS = {"true": True, "false": False, "null": None}


def error(line: int, message: str) -> SjsonError:
    return SjsonError("line %d: %s" % (line, message))


# Tokenizer


def skip_comment(text: str, index: int, line: int) -> Tuple[int, int]:
    if text.startswith("//", index):
        end = text.find("\n", index)
        return (len(text) if end < 0 else end), line
    end = text.find("*/", index + 2)
    if end < 0:
        raise error(line, "expected */ to close the block comment")
    return end + 2, line + text.count("\n", index, end)


def read_string(text: str, index: int, line: int) -> Tuple[str, int]:
    characters = []
    index += 1
    while index < len(text) and text[index] != '"':
        if text[index] == "\n":
            break
        if text[index] == "\\":
            character, index = read_escape(text, index, line)
        else:
            character, index = text[index], index + 1
        characters.append(character)
    if index >= len(text) or text[index] != '"':
        raise error(line, 'expected " to close the string')
    return "".join(characters), index + 1


def read_escape(text: str, index: int, line: int) -> Tuple[str, int]:
    escape = text[index + 1 : index + 2]
    if escape in SIMPLE_ESCAPES:
        return SIMPLE_ESCAPES[escape], index + 2
    digits = text[index + 2 : index + 6]
    if escape == "u" and re.fullmatch(r"[0-9A-Fa-f]{4}", digits):
        return chr(int(digits, 16)), index + 6
    raise error(line, "expected a valid string escape")


def read_number(text: str, index: int, line: int) -> Tuple[Any, int]:
    start = index + 1 if text[index] == "+" else index
    match = NUMBER_PATTERN.match(text, start)
    if match is None:
        raise error(line, "expected a number")
    literal = match.group(0)
    is_integer = match.group(1) is None and match.group(2) is None
    return (int(literal) if is_integer else float(literal)), match.end()


def read_token(text: str, index: int, line: int) -> Tuple[Token, int]:
    character = text[index]
    if character in PUNCTUATION:
        return Token("punctuation", character, line), index + 1
    if character == '"':
        value, index = read_string(text, index, line)
        return Token("string", value, line), index
    if character in "+-" or character.isdigit():
        value, index = read_number(text, index, line)
        return Token("number", value, line), index
    match = IDENTIFIER_PATTERN.match(text, index)
    if match is None:
        raise error(line, "expected a token, found %r" % character)
    return Token("identifier", match.group(0), line), match.end()


def tokenize(text: str) -> List[Token]:
    tokens = []
    index, line = 0, 1
    while index < len(text):
        if text[index] in WHITESPACE:
            line += text[index] == "\n"
            index += 1
        elif text.startswith("//", index) or text.startswith("/*", index):
            index, line = skip_comment(text, index, line)
        else:
            token, index = read_token(text, index, line)
            tokens.append(token)
    tokens.append(Token("end", None, line))
    return tokens


# Parser


class Parser:
    """Cursor over the token list; the parse procedures below advance it."""

    def __init__(self, tokens: List[Token]):
        self.tokens = tokens
        self.position = 0

    def peek(self) -> Token:
        return self.tokens[self.position]

    def advance(self) -> Token:
        token = self.tokens[self.position]
        self.position += 1
        return token


def is_punctuation(token: Token, character: str) -> bool:
    return token.kind == "punctuation" and token.value == character


def skip_optional_comma(parser: Parser) -> None:
    if is_punctuation(parser.peek(), ","):
        parser.advance()


def parse_key(parser: Parser) -> str:
    token = parser.advance()
    if token.kind in ("identifier", "string"):
        return token.value
    raise error(token.line, "expected a key")


def parse_separator(parser: Parser) -> None:
    token = parser.advance()
    if not (is_punctuation(token, "=") or is_punctuation(token, ":")):
        raise error(token.line, "expected = or : after the key")


def parse_members(parser: Parser, closing_kind: str, closing_value: Any) -> dict:
    members = {}
    while not (parser.peek().kind == closing_kind and parser.peek().value == closing_value):
        if parser.peek().kind == "end":
            raise error(parser.peek().line, "expected } to close the object")
        key_line = parser.peek().line
        key = parse_key(parser)
        if key in members:
            raise error(key_line, "duplicate key %s" % key)
        parse_separator(parser)
        members[key] = parse_value(parser)
        skip_optional_comma(parser)
    parser.advance()
    return members


def parse_array(parser: Parser) -> list:
    elements = []
    while not is_punctuation(parser.peek(), "]"):
        if parser.peek().kind == "end":
            raise error(parser.peek().line, "expected ] to close the array")
        elements.append(parse_value(parser))
        skip_optional_comma(parser)
    parser.advance()
    return elements


def parse_value(parser: Parser) -> Any:
    token = parser.advance()
    if is_punctuation(token, "{"):
        return parse_members(parser, "punctuation", "}")
    if is_punctuation(token, "["):
        return parse_array(parser)
    if token.kind in ("string", "number"):
        return token.value
    if token.kind == "identifier" and token.value in LITERALS:
        return LITERALS[token.value]
    raise error(token.line, "expected a value")


def parse(text: str) -> dict:
    """Parse SJSON text, with an implicit root object or one in braces, into a dict."""
    parser = Parser(tokenize(text))
    if not is_punctuation(parser.peek(), "{"):
        return parse_members(parser, "end", None)
    parser.advance()
    root = parse_members(parser, "punctuation", "}")
    if parser.peek().kind != "end":
        raise error(parser.peek().line, "expected the end of the text after the root object")
    return root
