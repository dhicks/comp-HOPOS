Readme update: 20180829 ####### Contact: Rick Morris (jemorr@ucdavis.edu)

###### Updates from last version: ######
- Change for readability and efficiency: restructured the script to run using objects rather than lists.
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
Use summary: From the shell, this script takes a CSV file (as the first argument, 
'SOMECSV.csv') and an output name string without an extension (as the second argument, 'EXAMPLE'), eliminates duplicate names, and returns both (1) an output file with duplicates stripped, and (2) an output file of possible duplicates left in the main file but flagged for the user to check manually. Names in (2) are flagged 'Check me' in (1). Sample command: py dupeRemove.py 'names.csv' 'example'.
--------------------------------------------------------------------------------
The standard key:value pair in the dictionary that's initially generated, off of which the list of objects is built:
'Full,name': [Primary Publications integer, Secondary Publications integer, family name string, given name string, [given name list of first and middle names as separate items], Boolean value True for non-duplicate, empty string '' for the warning flag, list of original names [origName]]. 
---------------------------------
#### Explanation of Entry object attributes. Entries built after initial dictionary-based checks and name-norming are done:
- item.canonName: the full working canonical name as a string in 'family,first middle' format.
- item.primPub: running primary pub total
- item.secPub: running secondary pub total
- item.origNames: list of names in original dataset which have been assigned as duplicates of this name.
- item.unique: Boolean value True for non-duplicate (changed to False if item is 
identified as a duplicate)
- item.warnFlag: empty string '', changed to the warning flag 'Check me' per (16) below.

#### Attributes created using the item.naming() method:
- item.namelist: splits canonName on the comma into list of strings['family','given']
- item.famName: string consisting only of family name
- item.givName: string consisting only of the given names
- item.givenlist: list of strings in the given name split on ' ' ['first','middle']
- item.firstName: first name, givenlist[0]
- item.firstInit: first initial, firstName[0]
- item.midName: middle name, either givenlist[1] or '' (depends on whether there is a middle name)
- item.midInit: middle initial, midName[0] or ''
--------------------------------------------------------------------------------
-----------OUTPUT FILE DICTIONARIES (for further details see below in steps 18-21).
---------------------------------
_output.csv: the main output file, giving canonical names and publication totals

COLUMN		PURPOSE
Family		Canonical family name of entry
Given		Canonical given name of entry
Primary		Total publications in a primary philosophy of science journal.
Secondary	Total publications in a secondary philosophy of science journal.
Warn		Default blank, "Check me" if script identifies possible match.
---------------------------------
_warnings.csv: all identified possible matches which are not actually removed from the final data set (flagged as "Check me" in _output.csv).

COLUMN		PURPOSE
Family		Canonical family name of flagged name
Given		Canonical given name of flagged name
---------------------------------
_verif.csv: list of all original input names paired with canonical names to allow confirmation of matches.

COLUMN			PURPOSE
Orig Family		Input family name
Orig Given		Input given name
Canonical Family	Canonical family name
Canonical Given		Canonical given name
---------------------------------
_anag.csv: list of all names which are identified as anagrams of another name after normName() has been run on the raw input names.

COLUMN		PURPOSE
Orig Family	Input family name
Orig Given	Input given name
Norm Family	Normed family name
Norm Given	Normed given name
Anagr Family	Canonical name identified as anagram of normed family name
Anagr Given	Canonical name identified as anagram of normed given name
--------------------------------------------------------------------------------
Possible problematic content assumptions:
- All true duplicates will match in the first two letters of the family name.
- Family names of length 1 combined with a given name of length 3 or less are simply mistakes and are not processed for further use, e.g. 'a,p h' (lines 215-216). If this is changed, be sure to adjust the givenDist checks (lines 148-151 in spellCheck() as well, to ensure that 'a,p h' and 'a,j t' are not considered duplicates.
--------------------------------------------------------------------------------
Formatting assumptions: 
- UTF-8 CSV: easily modified by removing the encoding arguments in lines 188, 298, 324, 340.
- Row with column labels at top: remove line 190; modify lines 300, 312, 326, 342 as appropriate.
- Input CSV with columns representing Family Name, Given Name, Primary Pubs, Secondary Pubs: can change name order assumptions by manipulating the order in which things are read from the CSV into the dictionary (lines 209-225); can change pub column assumptions by modifying how the objects are built in lines 227-235, particularly 230 and 231.
--------------------------------------------------------------------------------
Functional summary (numbers not annotated in the script, but this is in reading order):
(1) Define the Entry object. Attributes of an Entry are explained above. 

### Define functions ###
(2) Define normName function, which removes all periods and other non-alphanumeric characters from names, ensures consistent whitespace characters, turns all accented characters into nearest ASCII equivalents, and replaces the name 'wm ' with 'william'. Remove 'de X'-type locutions. Returns the name.

(3) Define alphaIndex function, which first identifies where each first letter starts and stops in the alphabetically sorted list of names, and then does the same for each second letter. This shrinks the search space: items with 'aa'-starting family names are only compared to others with an 'aa' name. Runtime benefit is close to two orders of magnitude. Returns a dictionary with two-character string as a key and a list of two integers (start/stop) as the value.

(4) Define nullStrip(), which identifies all flagged non-canonical duplicates and removes them from the final list. Returns a list.

(5) Define subSCheck(), which checks for substrings. 'hicks,dan' is considered a duplicate of canonical 'hicks,daniel j'. subSCheck() also looks for matches of initials and matches of middle names to first names: 'akeroyd,f michael' is canonical version of 'akeroyd,michael'. Returns a Boolean.

(6) Define spellCheck(), which looks for family names which only show up oncewith one publication and matches them to other family names at a Levenshtein distance of <=2 and more publications, and matching items with a given namewith a matching family name, one publication, and a Levenshtein distance of <=2.Returns a Boolean.

(7) Define isDuplicate(), which calls subSCheck() and spellCheck() on items being compared (in one direction of comparison). Returns a Boolean.

(8) Define pubUpdate(), which takes two items, a duplicate and a canonical name, then updates item.primPub and item.secPub (the primary and secondary pub totals). Returns the item.

(9) Define notifyUser(), which looks for possible duplicates, defined as names where the family name matches and the given name is at a Levenshtein distance of <=3 (catches, e.g. 'joseph' vs. 'jozef'). Returns a Boolean. 
### Functions all defined. ###

### Begin main body of program ###
(10) Get a filename from the command line (first argument), open that file as a UTF-8. Remove header row. Make a CSV Reader object.

(11) Initialize the needed dictionaries, lists, and set. 

(12) Get destination file name (leave off .csv extension) as the second argument.

(13) Loop through each row in the Reader. Call normName() on the family and given names. Turn the names into one string separated by a comma: 'family,given'. Check for possible anagrams with spaces stripped out (e.g. 'abiram' and 'abi ram') using sorted(). Remove names which consist entirely of initials. Check to see if the sorted name is already in the dictionary of sorted names. If not, add it to the dictionary as a key with the full name as the value and add the full name to the destination dictionary (with all the data) as a key with the value a list as such: 

- 'Family,given': [Primary Publications integer, Secondary Publications integer, list of original names [origName]]. 

If the sorted name is in the family name dictionary as a key already, then use the corresponding value (the full name) to update the item in the destination  dictionary by adding the pub totals together. Also append new origName to [2] in the list of values.

(14) Loop through the key-value pairs [k, v] in the destination dictionary to build a list of Entry objects. Call alphaIndex() on the list to generate the dictionary of start/stop indices for comparison, described in (3) above.

(15) Add the family names of each name to a list of family names, which are then counted for number of appearances. The family name then becomes a key and the total number of appearances becomes a value in countDict (used in spellCheck() in (6) above.

(16) Loop through each key in alphaDict (described in (3) above) and get startIndex and stopIndex to identify where comparisons start and stop. For each key, loop through all the items in the list in the range from the start index to stop index, with each item called itemOne. Check to make sure that itemOne.unique is not set to False, denoting a previously-identified duplicate. If it is, move to the next item in the loop. If not, begin innermost loop, looping through each item (itemTwo) starting after current item and until the stopIndex. Call isDuplicate(), (7) above, first to see if itemOne is a duplicate of itemTwo. If isDuplicate() returns True, then change itemOne.unique to False and run pubUpdate to add itemOne's publication totals to itemTwo's. If isDuplicate() returns False, then check to see if itemTwo is a duplicate of itemOne (and do the converse updating as above). If both return False, call notifyUser(), (9) above, to see if they are possible duplicates. If notifyUser() returns True, then change itemOne.warnFlag and itemTwo.warnFlag to 'Check me', add both items to warn set for the manual check CSV, and continue to the next item. Otherwise, continue to the next item until stopIndex is reached, then move to the next item in the secondary loop and run the same process until each item within a starting-character-defined portion of the list is checked. Then move to the next item in alphaDict and start all over.

(17) Call nullStrip(), (4) above, to remove all items from the list identified as duplicates and output to FinalList. 

(18) loop through all output items in FinalList, initializing canonName, the canonical name, as item.canonName. For each item, loop through the list of original names in item.origNames and append [origName, canonName] to checkList. Then sort checkList.

(18) Open a destination CSV file as destName+'_output.csv'. (destName from (3) above.) Write a row of column headings. Then write the full canonical family and given names as the first two columns, and item.primPub and item.secPub to the third and fourth columns. Put the canonical names into title case using string.capwords(). Write item.warnFlag to the fifth column, indicating whether the user ought to manually check the item as a possible duplicate. ('Check me' if yes, blank if no.)

(19) Open a warning CSV file using the same naming convention as above, but with '_warnings_' instead of '_output_'. Write all the names from warnList into the CSV so that the user can see how many possible duplicates remain to be checked.

(20) Write an output CSV (encoded as UTF-8 due to data input) with column headings 'Orig Family','Orig Given', 'Canonical Family', 'Canonical Given'. Check if the original name has a double comma ('X,,Y Z'), which will mess up the CSV. Depending on result, split on ',' or ',,'. Output CSV is destName + '_verif.csv'.

(21) Write destName + '_anag.csv', listing all identified anagrams (used to catch names out of order), and write them to a csv.

(22) Close all files.
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------