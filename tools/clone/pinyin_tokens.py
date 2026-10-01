"""Text for CosyVoice 3 with the tones spelled out: its "pronunciation inpainting" takes pinyin as
[initial][final] tokens, the final carrying the tone mark (给 → [g][ěi]), so the model can't pick
the wrong tone. A syllable it has no token for is left as its character.

    from pinyin_tokens import spelled
    spelled("汉语", "hàn yǔ")      # → "[h][àn][y][ǔ]"
"""
import re
import unicodedata

# the model's own tokens (cosyvoice/tokenizer/tokenizer.py, CosyVoice3Tokenizer)
TOKENS = set("""a ai an ang ao b c ch d e ei en eng f g h i ian in ing iu ià iàn iàng iào iá ián iáng iáo iè ié iòng
ióng iù iú iā iān iāng iāo iē iě iōng iū iǎ iǎn iǎng iǎo iǒng iǔ j k l m n o ong ou p q r s sh t u uang ue un uo uà
uài uàn uàng uá uái uán uáng uè ué uì uí uò uó uā uāi uān uāng uē uě uī uō uǎ uǎi uǎn uǎng uǐ uǒ vè w x y z zh à ài
àn àng ào á ái án áng áo è èi èn èng èr é éi én éng ér ì ìn ìng í ín íng ò òng òu ó óng óu ù ùn ú ún ā āi ān āng āo
ē ēi ēn ēng ě ěi ěn ěng ěr ī īn īng ō ōng ōu ū ūn ǎ ǎi ǎn ǎng ǎo ǐ ǐn ǐng ǒ ǒng ǒu ǔ ǔn ǘ ǚ ǜ""".split())
INITIALS = ["zh", "ch", "sh", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "r", "z", "c", "s",
            "y", "w"]


def is_han(c):
    return "一" <= c <= "鿿"


def syllable(py):
    """One syllable (hàn) as tokens ([h][àn]), or None when the model has no token for it."""
    s = unicodedata.normalize("NFC", py.lower().replace("v", "ü"))
    ini = next((i for i in INITIALS if s.startswith(i) and len(s) > len(i)), "")
    fin = s[len(ini):]
    # (the model's tokens follow written pinyin: qù is [q][ù], yǔ is [y][ǔ]; ü only after l and n)
    if fin not in TOKENS or (ini and ini not in TOKENS):
        return None
    return (f"[{ini}]" if ini else "") + f"[{fin}]"


def syllables(py):
    """A pinyin string's syllables, one per character (spaces, apostrophes and r of erhua aside)."""
    out = []
    for tok in re.split(r"[\s'’,.!?;:，。！？]+", py):
        if not tok:
            continue
        # split joined syllables (nǐhǎo) at each new initial after a vowel
        out += re.findall(r"(?:zh|ch|sh|[bpmfdtnlgkhjqxrzcsyw])?[^bpmfdtlgkhjqxrzcsyw\s]*?(?:ng|n(?![aeiouüāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ])|r(?![aeiouüāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]))?(?=[bpmfdtnlgkhjqxrzcsyw]|$)", tok.lower())
    return [o for o in out if o]


def spelled(hanzi, py, only=None):
    """The text with each character (or only those in `only`) replaced by its tokens; a
    character whose syllable doesn't line up or has no tokens stays as it is."""
    chars = [c for c in hanzi if is_han(c)]
    sy = [s for s in syllables(py) if s != "r"]
    # erhua (一点儿 yīdiǎnr): the 儿 has no syllable of its own and stays a character
    erhua = len(sy) == len(chars) - chars.count("儿")
    if len(sy) != len(chars) and not erhua:
        return None
    out, k = [], 0
    for c in hanzi:
        if erhua and c == "儿":
            out.append(c)
        elif is_han(c):
            t = syllable(sy[k]) if (only is None or c in only) else None
            out.append(t or c)
            k += 1
        else:
            out.append(c)
    return "".join(out)


if __name__ == "__main__":
    import sys
    sys.stdout.reconfigure(encoding="utf-8")
    for h, p in [("汉语", "hàn yǔ"), ("你好，马克！", "nǐhǎo, Mǎkè!"), ("去", "qù"), ("一点儿", "yī diǎn r"),
                 ("月", "yuè"), ("女", "nǚ"), ("学", "xué"), ("想", "xiǎng"), ("几", "jǐ"), ("吧", "ba")]:
        print(h, p, "→", spelled(h, p))
