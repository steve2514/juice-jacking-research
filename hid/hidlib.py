#!/usr/bin/env python3
import time, os
from typing import Iterable

HIDDEV = os.environ.get("HIDDEV", "/dev/hidg0")

MOD = {"LCTRL":1,"LSHIFT":2,"LALT":4,"LGUI":8,"RCTRL":16,"RSHIFT":32,"RALT":64,"RGUI":128}

KEY = {
    "ENTER":0x28,"ESC":0x29,"BACKSPACE":0x2A,"TAB":0x2B,"SPACE":0x2C,
    "1":0x1E,"2":0x1F,"3":0x20,"4":0x21,"5":0x22,"6":0x23,"7":0x24,"8":0x25,"9":0x26,"0":0x27,
    "A":0x04,"B":0x05,"C":0x06,"D":0x07,"E":0x08,"F":0x09,"G":0x0A,"H":0x0B,"I":0x0C,"J":0x0D,"K":0x0E,"L":0x0F,"M":0x10,
    "N":0x11,"O":0x12,"P":0x13,"Q":0x14,"R":0x15,"S":0x16,"T":0x17,"U":0x18,"V":0x19,"W":0x1A,"X":0x1B,"Y":0x1C,"Z":0x1D,
    "-":0x2D,"=":0x2E,"[":0x2F,"]":0x30,"\\":0x31,";":0x33,"'":0x34,"`":0x35,",":0x36,".":0x37,"/":0x38,
}

SHIFTED = {
    "!":"1","@":"2","#":"3","$":"4","%":"5","^":"6","&":"7","*":"8","(":"9",")":"0",
    "_":"-","+":"=","{":"[","}":"]","|":"\\",":":";","\"":"'", "~":"`","<":",",">":".","?":"/",
}

def _report(mod:int, keys:Iterable[int]) -> bytes:
    k = list(keys)[:6] + [0]*(6-len(list(keys)[:6]))
    return bytes([mod & 0xFF, 0x00, *k])

def write_report(rep:bytes):
    if len(rep)!=8: raise ValueError("HID report must be 8 bytes")
    with open(HIDDEV, "wb", buffering=0) as f:
        f.write(rep)

def press(mod:int=0, *keycodes:int, hold:float=0.06):
    write_report(_report(mod, keycodes)); time.sleep(hold)

def release(hold:float=0.02):
    write_report(b"\x00\x00\x00\x00\x00\x00\x00\x00"); time.sleep(hold)

def tap(mod:int=0, *keycodes:int, hold:float=0.06):
    press(mod, *keycodes, hold=hold); release()

def type_char(ch:str, base_hold:float=0.05):
    if ch==" ": tap(0, KEY["SPACE"], hold=base_hold); return
    if ch=="\n": tap(0, KEY["ENTER"], hold=base_hold); return
    if "A"<=ch<="Z": tap(MOD["LSHIFT"], KEY[ch], hold=base_hold); return
    if "a"<=ch<="z": tap(0, KEY[ch.upper()], hold=base_hold); return
    if ch.isdigit(): tap(0, KEY[ch], hold=base_hold); return
    if ch in SHIFTED: tap(MOD["LSHIFT"], KEY[SHIFTED[ch]], hold=base_hold); return
    if ch in KEY: tap(0, KEY[ch], hold=base_hold); return
    raise ValueError(f"Unsupported char: {repr(ch)} (US layout)")

def type_text(text:str, wpm:int=240):
    base_hold = max(0.015, 60.0 / max(30, wpm) / 5.0)
    for ch in text: type_char(ch, base_hold)