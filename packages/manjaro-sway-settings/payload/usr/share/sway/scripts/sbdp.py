#!/usr/bin/python
import sys
import glob
import re
from typing import Text
import json

if len(sys.argv) >= 2:
    rootPath = sys.argv[1]
else:
    rootPath = '/etc/sway/config'


def readFile(filePath):
    try:
        paths = glob.glob(filePath)
    except:
        print("couldn't resolve glob:", filePath)
        paths = []

    allLines: list[str] = []
    for path in paths:
        allLines = allLines + open(path, "r").readlines()

    finalLines: list[str] = []
    for line in allLines:
        if re.search(r'^include\s+(.+?)$', line):
            nextPath = re.findall(r'^include\s+(.+?)$', line)[0]
            finalLines = finalLines + readFile(nextPath)
        else:
            finalLines = finalLines + [line]

    return finalLines


lines = readFile(rootPath)


def findKeybindingForLine(lineNumber: int, lines: list[str]):
    return lines[lineNumber+1].split(' ')[1]


class DocsConfig:
    category: Text
    action: Text
    keybinding: Text


def getDocsConfig(lines: list[str]):
    docsLineRegex = r"^## (?P<category>.+?) // (?P<action>.+?)\s+(// (?P<keybinding>.+?))*##"
    docsConfig: list[DocsConfig] = []
    for index, line in enumerate(lines):
        match = re.match(docsLineRegex, line)
        if (match):
            config = DocsConfig()
            config.category = match.group('category')
            config.action = match.group('action')
            config.keybinding = match.group('keybinding')
            if (config.keybinding == None):
                config.keybinding = findKeybindingForLine(index, lines)
            docsConfig = docsConfig + [config]
    return docsConfig


def getSymbolDict(lines: list[str]):
    setRegex = r"^set\s+(?P<variable>\$.+?)\s(?P<value>.+)?"
    dictionary = {}
    for line in lines:
        match = re.match(setRegex, line)
        if (match):
            if (match.group('variable')):
                dictionary[match.group('variable')] = match.group('value')
    return dict(dictionary)


translations = {
    'Mod1': "Alt",
    'Mod2': "",
    'Mod3': "בּ",
    'Mod4': "",
    'Mod5': "Scroll",
    'question': "?",
    #'Shift': "וּ",
    'space': "␣",
    'minus': "-",
    'plus': '+',
    'Return': "",
    'XF86AudioRaiseVolume': "ﱛ",
    'XF86AudioLowerVolume': "ﱜ",
    'XF86AudioMute': "ﱝ",
    'XF86AudioMicMute': '',
    'XF86MonBrightnessUp': "",
    'XF86MonBrightnessDown': "",
    'XF86PowerOff': "襤",
    'XF86TouchpadToggle': "Toggle Touchpad"
}

def translate(word: Text, dictionary: dict):
    try:
        return dictionary[word.strip()]
    except:
        return word.strip()


def replaceBindingFromMap(binding: Text, dictionary: dict):
    elements = binding.split('+')
    resultElements = []
    for el in elements:
        translation = translate(translate(el, dictionary), translations)
        resultElements = resultElements + [translation]
    
    return " + ".join(resultElements)


def sanitize(configs: list[DocsConfig], symbolDict: dict):
    for index, config in enumerate(configs):
        config.keybinding = replaceBindingFromMap(config.keybinding, symbolDict)
        configs[index] = config
    return configs


def getDocsList(lines: list[str]):
    docsConfig = getDocsConfig(lines)
    symbolDict = getSymbolDict(lines)
    sanitizedConfig = sanitize(docsConfig, symbolDict)
    return sanitizedConfig


def getManConfigs(docs: list[DocsConfig]):
    manConfigs = {}
    for doc in docs:
        current = [
            '',
            '.B ' + doc.action + ': ',
            '.I ' + doc.keybinding
        ]
        try:
            manConfigs[doc.category] = manConfigs[doc.category] + ['\n'.join(current)]
        except:
            manConfigs[doc.category] = current
    return dict(manConfigs)


def parseManPageConfig(manContent: dict):
    elements = []
    for key in manContent:
        elements = elements + ["", '.SS ' + key, ""]
        value = manContent[key]
        for line in value:
            elements = elements + [line]
    result = '\n'.join(elements)
    print(result)


docsList = getDocsList(lines)

if len(sys.argv) >= 3 and sys.argv[2] == 'man':
    print('man')
    manContent = getManConfigs(docsList)
    manPage = parseManPageConfig(manContent)
else:
    result = []
    for config in docsList:
        result = result + [{'category': config.category,
                            'action': config.action, 'keybinding': config.keybinding}]
    print(json.dumps(result))
