#! python3
# From the shell, this script takes a CSV file (as the first argument, 'SOMECSV.csv') and an output name string without an extension (as the second argument, 'EXAMPLE'), eliminates duplicate names, and returns both (1) an output file with duplicates stripped, (2) an output file of possible duplicates left in the main file, (3) an output file of all original names paired with canonical names, (4) a list of anagrams identified. Names in (2) are flagged 'Check me' in (1). Sample command: py dupeRemove.py 'names.csv' 'example'.
# Changes in v4, 20180728: line 47, added +1 to the end. lines 62-64, removed extra call of .index() method. line 105 uses .startswith() method. line 107 adds len()>1 check to avoid overly-aggressive matching of initials as substrings.

import os, sys, csv, re, unicodedata, time, string
from datetime import datetime
from pyxdameraulevenshtein import damerau_levenshtein_distance as distance
from collections import Counter
from string import ascii_lowercase
############################################################
### Define the object class ###
class Entry(object): 
    def __init__(self):
        self.canonName = ''
        self.primPub = 0
        self.secPub = 0
        self.origNames = []
        self.unique = True
        self.warnFlag = ''
    
    def naming(self):
        self.namelist = self.canonName.split(',')
        self.famName = self.namelist[0]
        self.givName = self.namelist[1]
        self.givenlist = self.givName.split(' ')
        self.firstName = self.givenlist[0]
        self.firstInit = self.firstName[0]
        try:
            self.midName = self.givenlist[1]
            self.midInit = self.midName[0]
        except IndexError:
            self.midName = ''  
            self.midInit = ''
############################################################
### Define functions ###
# normName normalizes the names by stripping out odd characters. 
def normName(name):
    name = name.lower()
    badChars = "'.,’`()?"
    name = ' '.join(name.split())
    name = re.sub(r"(\.)(\w)", r"\1 \2", name)
    name = re.sub(r"(\w)(-)(\w)", r"\1 \3", name)
    for ch in badChars:
        if ch in name:
            name = name.replace(ch, '')
    name = unicodedata.normalize('NFKD', name).encode('ASCII', 'ignore').decode('UTF-8')
    name = re.sub(r"wm ", r"william ", name)
    if name.startswith('de '):
        name = name.replace('de ', '')
    if ' de ' in name:
        name = name.replace(' de ', ' ')
    if name.endswith(' de'):
        name = name.replace(' de', '')
    return name

# alphaIndex: build dictionary with letters as keys and indices as list of start/stop values of the sorted list. 
def alphaIndex(somelist, somedict):
    a = 0
    b = len(somelist)
    lastChar = ''
    initDict = {}
    for ch in ascii_lowercase:
        for item in somelist[a:b]:
            if item.canonName.startswith(ch):
                initDict[ch] = [0,b]
                initDict[ch][0] = somelist.index(item)
                a = somelist.index(item)
                break
        if lastChar != '':
            initDict[lastChar][1] = somelist.index(item) + 1
        if ch in initDict.keys():
            lastChar = ch
    # Now create somedict with two-character string keys.
    lastStr = ''
    azSpStr = ' ' + ascii_lowercase
    for char1 in initDict:
        startIndex = initDict[char1][0]
        stopIndex = initDict[char1][1]
        i = 0
        while i < len(azSpStr):
            char2 = azSpStr[i]
            stStr = char1 + char2
            for item in somelist[startIndex:stopIndex]:
                if item.canonName.startswith(stStr):
                    somedict[stStr] = [0,stopIndex]
                    a = somelist.index(item)
                    somedict[stStr][0] = a
                    break
            if lastStr != '':
                somedict[lastStr][1] = somelist.index(item) + 1
            if stStr in somedict:
                lastStr = stStr
            i += 1
    return somedict

# nullStrip: create a finalized list with only True for item.unique.
def nullStrip(inList,outList):
    for item in inList:
        if item.unique == True:
            outList.append(item)
    return outList

# Check for substrings and close initial matches.
def subSCheck(itemOne,itemTwo):
    if itemOne.canonName in itemTwo.canonName and itemOne != itemTwo:
        return True
    elif itemOne.givName != '' and itemTwo.givName != '':
        if len(itemTwo.givenlist) > 1:
            itemOneSurname = itemOne.famName
            itemTwoSurname = itemTwo.famName
            if itemOneSurname == itemTwoSurname:
                itemOneFirst = itemOne.firstName
                itemOneFI = itemOne.firstInit
                itemTwoFirst = itemTwo.firstName
                itemTwoFI = itemTwo.firstInit
                itemOneMiddle = itemOne.midName
                itemOneMI = itemOne.midInit
                itemTwoMiddle = itemTwo.midName
                itemTwoMI = itemTwo.midInit
                if itemTwoFirst.startswith(itemOneFirst) and itemTwoMiddle.startswith(itemOneMiddle) and itemOneMiddle != '': 
                    return True
                elif itemOneFI == itemTwoFI and itemOneMI == itemTwoMI and len(itemOneFirst) == 1:
                    return True
                elif itemTwoMiddle == itemOneFirst and itemOneMiddle == '' and len(itemTwoMiddle) > 1:
                    return True
    return False

# Check for spelling variants.
def spellCheck(itemOne,itemTwo,totalcount):
    itemOneSurname = itemOne.famName
    itemTwoSurname = itemTwo.famName
    itemOneFirst = itemOne.firstName
    itemTwoFirst = itemTwo.firstName
    itemOnePub = itemOne.primPub + itemOne.secPub
    itemTwoPub = itemTwo.primPub + itemTwo.secPub
    itemOneMiddle = itemOne.midName
    itemTwoMiddle = itemTwo.midName
    if totalcount[itemOneSurname] == 1 and itemOnePub == 1 and itemOneSurname != itemTwoSurname:
        if itemTwoPub >= 2:
            surnameDist = distance(itemOneSurname,itemTwoSurname)
            if surnameDist <= 2:
                if itemTwoFirst.startswith(itemOneFirst): 
                    if itemOneMiddle != '' and itemTwoMiddle != '' and itemTwoMiddle.startswith(itemOneMiddle):
                        return True
                    elif itemOneMiddle == '' and itemTwoMiddle == '':
                        return True
    elif itemOneSurname == itemTwoSurname and itemOnePub == 1:
        givenDist = distance(itemOneFirst,itemTwoFirst)
        if givenDist <= 1 and len(itemOneFirst) > 1 and len(itemTwoFirst) > 1:
            if itemOneMiddle == itemTwoMiddle:
                return True
    return False

# Main duplicate-checking function.
def isDuplicate(itemOne, itemTwo, count):
    if subSCheck(itemOne, itemTwo) == True:
        return True
    elif spellCheck(itemOne, itemTwo, count) == True:
        return True
    else:
        return False

# Pub total updating function.
def pubUpdate(itemOne, itemTwo):
    itemTwo.primPub += itemOne.primPub
    itemTwo.secPub += itemOne.secPub
    return itemTwo

# ID possible duplicates for manual check.
def notifyUser(itemOne,itemTwo):
    itemOneGiven = itemOne.givName
    itemOneFI = itemOne.firstInit
    itemOneSurname = itemOne.famName
    itemTwoGiven = itemTwo.givName
    itemTwoFI = itemTwo.firstInit
    itemTwoSurname = itemTwo.famName
    givenDist = distance(itemOneGiven,itemTwoGiven)
    if itemOneSurname == itemTwoSurname and itemOneFI == itemTwoFI and givenDist <= 3:
        return True
    else:
        return False

if __name__ == '__main__':
    start = time.perf_counter()
    ############################################################
    # Read all-lowercase CSV file into a CSV Reader Object.
    file = sys.argv[1]
    origFile = open(file, 'r', encoding ='utf8')
    origFileList = [line for line in origFile]
    origFileList.pop(0) # Remove header line
    origReader = csv.reader(origFileList)

    ### Define starting dictionaries, lists, set. ###
    origList = []
    anaDict = {}
    anaOutDict = {}
    destDict = {}
    keyDict = {}
    alphaDict = {}
    famList = []
    finalList = []
    checkList = []
    warnSet = set()
    ### Get name of destination file ###
    destName = sys.argv[2]
    ############################################################
    ### Create the dataset to use. ###
    # Create destDict from the list of CSV lines.
    for k1,k2,v1,v2 in origReader:
        origName = (k1+','+k2)
        k1 = normName(k1)
        k2 = normName(k2)
        fullName = (k1+','+k2)
        sortName = tuple(sorted(fullName.replace(' ', '')))
        if len(k1) == 1 and len(k2) <= 3:
            checkList.append([origName,'IGNORED,IGNORED'])
            continue
        if sortName not in keyDict.keys():
            keyDict[sortName] = fullName
            destDict[fullName] = [int(v1), int(v2),[origName]]
        else:
            anaDict[origName] = [fullName,keyDict[sortName]]
            destDict[keyDict[sortName]][0] += int(v1)
            destDict[keyDict[sortName]][1] += int(v2)
            destDict[keyDict[sortName]][2].append(origName)
    # Turn dictionary into a sorted list. Find list indexes for start of each letter. Find total occurrences of each family name.
    for k, v in destDict.items():
        x = Entry()
        x.canonName = k
        x.primPub = v[0]
        x.secPub = v[1]
        x.unique = True
        [x.origNames.append(item) for item in v[2]]
        x.naming()
        origList.append(x)

    origList.sort(key = lambda x: x.canonName, reverse = False)
    alphaIndex(origList,alphaDict)

    for name in origList:
        famList.append(name.famName)

    countDict = Counter(famList)
    ############################################################
    ### Main iterations of the program. ###
    for char in alphaDict:
        startIndex = alphaDict[char][0]
        stopIndex = alphaDict[char][1]
        for ndxOne in range(startIndex,(stopIndex-1)):
            itemOne = origList[ndxOne]
            if itemOne.unique == False:
                continue
            ## Begin the comparison for loop. ##
            for ndxTwo in range(ndxOne+1,stopIndex):
                itemTwo = origList[ndxTwo]
                if itemTwo.unique == False: # Continue if itemTwo is previously identified duplicate.
                    continue
                # Use isDuplicate to look for duplicates.
                if isDuplicate(itemOne,itemTwo,countDict) == True:
                    pubUpdate(itemOne,itemTwo)
                    itemOne.unique = False
                    [itemTwo.origNames.append(x) for x in itemOne.origNames]
                    break
                elif isDuplicate(itemTwo,itemOne,countDict) == True:
                    pubUpdate(itemTwo,itemOne)
                    itemTwo.unique = False
                    [itemOne.origNames.append(x) for x in itemTwo.origNames]
                    continue
                elif notifyUser(itemOne,itemTwo) == True:
                    warnSet.add(itemOne.canonName)
                    warnSet.add(itemTwo.canonName)
                    itemOne.warnFlag = 'Check me'
                    itemTwo.warnFlag = 'Check me'
                    continue

    nullStrip(origList,finalList)
    ############################################################
    ### Create dictionary of original names paired to canonical names ###
    for item in finalList:
        canonName = item.canonName
        for origName in item.origNames:
            checkList.append([origName,canonName])

    checkList = sorted(checkList)
    ############################################################
    ## Modify anaDict to create shortened list of identified anagrams (removing letter-for-letter matches in original) and output anaOutDict.

    for item in anaDict.items():
        k, v = item
        if v[0].lower() != v[1].lower():
            anaOutDict[k] = v
        else:
            pass

    ############################################################
    # write the list of canonical names and publication totals to the output.csv file
    destFile = open(destName + '_output' + # datetime.now().strftime('%Y%m%d%H%M') +
        '.csv', 'w', newline='')
    outputWriter = csv.writer(destFile)
    outputWriter.writerow(['Family','Given','Primary','Secondary','Warn'])

    for item in finalList:
        try:
            outputWriter.writerow([string.capwords(item.canonName.split(',')[0]),string.capwords(item.canonName.split(',')[1]),item.primPub,item.secPub,item.warnFlag])
        except:
            pass

    # write the list of flagged names to the warnings.csv file
    warnFile = open(destName + '_warnings' + # datetime.now().strftime('%Y%m%d%H%M') +
        '.csv', 'w', newline='')
    warnWriter = csv.writer(warnFile)
    warnWriter.writerow(['Family','Given'])
    warnList = list(warnSet)
    warnList = sorted(warnList)

    for item in warnList:
        try:
            warnWriter.writerow([string.capwords(item.split(',')[0]),string.capwords(item.split(',')[1])])
        except:
            pass

    # write the list of original names paired with canonical names to the verif.csv file
    veriFile = open(destName + '_verif' + # datetime.now().strftime('%Y%m%d%H%M') +
        '.csv', 'w', newline='',encoding='utf8')
    veriWriter = csv.writer(veriFile)
    veriWriter.writerow(['Orig Family','Orig Given', 'Canonical Family', 'Canonical Given'])

    for item in checkList:
        try:
            if ',,' in item[0]:
                veriWriter.writerow([item[0].split(',,')[0] + ',',item[0].split(',,')[1],string.capwords(item[1].split(',')[0]),string.capwords(item[1].split(',')[1])])
            else:
                veriWriter.writerow([item[0].split(',')[0],item[0].split(',')[1],string.capwords(item[1].split(',')[0]),string.capwords(item[1].split(',')[1])])
        except:
            print(item)
            pass

    # write a list of original names paired with the same name after normName is applied and again after the name is identified as an anagram (possible match of rearranged names). write to anag.csv
    anaFile = open(destName + '_anag' + # datetime.now().strftime('%Y%m%d%H%M') +
        '.csv', 'w', newline='',encoding='utf8')
    anaWriter = csv.writer(anaFile)
    anaWriter.writerow(['Orig Family','Orig Given', 'Norm Family', 'Norm Given', 'Anagr Family', 'Anagr Given'])

    for k, v in anaOutDict.items():
        try:
            if ',,' in k:
                anaWriter.writerow([k.split(',,')[0] + ',',k.split(',,')[1],string.capwords(v[0].split(',')[0]),string.capwords(v[0].split(',')[1]),string.capwords(v[1].split(',')[0]),string.capwords(v[1].split(',')[1])])
            else:
                anaWriter.writerow([k.split(',')[0],k.split(',')[1],string.capwords(v[0].split(',')[0]),string.capwords(v[0].split(',')[1]),string.capwords(v[1].split(',')[0]),string.capwords(v[1].split(',')[1])])
        except:
            print(item)
            pass

    # Close the files
    origFile.close()
    destFile.close()
    warnFile.close()
    veriFile.close()
    anaFile.close()
    end = time.perf_counter()
    perfTime = (end - start)
    print(perfTime)
