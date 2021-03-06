Script/readme update: 20180729 ####### Contact: Rick Morris (jemorr@ucdavis.edu)

###### Updates from last version: ######
- line 47, added +1 to the end to ensure that final item on list is checked. 
(Previous version worked on full data set but not on short datasets; this works 
on both.)
- lines 62-64, removed extra call of .index() method. Small optimization change.
- line 105 uses .startswith() method line 107 adds len()>1 check to avoid overly-
aggressive matching of initials as substrings. (Was previously checking for the 
initial *in* the first/middle name, which caused 'r' to match on 'robert' *and*
on 'gregory'.)
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
Use summary: From the shell, this script takes a CSV file (as the first argument, 
'SOMECSV.csv') and an output name string without an extension (as the second 
argument, 'EXAMPLE'), eliminates duplicate names, and returns both (1) an output 
file with duplicates stripped, and (2) an output file of possible duplicates left 
in the main file but flagged for the user to check manually. Names in (2) are 
flagged 'Check me' in (1). Sample command: py dupeRemove.py 'names.csv' 'example'.
--------------------------------------------------------------------------------
The standard key:value pair in the dictionary that's initially generated:
'Full,name': [Primary Publications integer, Secondary Publications integer, 
family name string, given name string, [given name list of first and middle names 
as separate items], Boolean value True for non-duplicate, empty string '' for the 
warning flag, list of original names [origName]]. 
---------------------------------
Explanation of item indices after dictionary-based checks are done:
item[0]: the full working canonical name as a string in 'family,first middle' format.
item[1]: list of everything else, as below.
item[1][0]: running primary pub total
item[1][1]: running secondary pub total
item[1][2]: family name string
item[1][3]: given name string
item[1][4]: list of strings within given name [first, middle]
item[1][5]: Boolean value True for non-duplicate (changed to False if item is 
identified as a duplicate)
item[1][6]: empty string '', changed to the warning flag 'Check me' per (15) in the 
readme.
item[1][7]: list of original, non-normed, non-canonical names [oldname1,oldname2...] 
to generate the verification file.
--------------------------------------------------------------------------------
OUTPUT FILE DICTIONARIES (for further details see below in steps 18-21).
---------------------------------
_output.csv: the main output file, giving canonical names and publication totals

COLUMN		PURPOSE
Family		Canonical family name of entry
Given		Canonical given name of entry
Primary		Total publications in a primary philosophy of science journal.
Secondary	Total publications in a secondary philosophy of science journal.
Warn		Default blank, "Check me" if script identifies possible match.
---------------------------------
_warnings.csv: all identified possible matches which are not actually removed
from the final data set (flagged as "Check me" in _output.csv).

COLUMN		PURPOSE
Family		Canonical family name of flagged name
Given		Canonical given name of flagged name
---------------------------------
_verif.csv: list of all original input names paired with canonical names to
allow confirmation of matches.

COLUMN			PURPOSE
Orig Family		Input family name
Orig Given		Input given name
Canonical Family	Canonical family name
Canonical Given		Canonical given name
---------------------------------
_anag.csv: list of all names which are identified as anagrams of another name
after normName() has been run on the raw input names.

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
- Family names of length 1 combined with a given name of length 3 or less are 
simply mistakes and are not processed for further use, e.g. 'a,p h' (lines 
189-90). If this is changed, be sure to adjust the givenDist checks (lines 146-9)
in subSCheck() as well, to ensure that 'a,p h' and 'a,j t' are not considered
duplicates.
--------------------------------------------------------------------------------
Formatting assumptions: 
- UTF-8 CSV: easily modified by removing the encoding arguments in lines 14, 287.
- Row with column labels at top: remove line 16; modify lines 240 and 251 as
appropriate.
- Columns representing Family Name, Given Name, Primary Pubs, Secondary Pubs: can
change name order assumptions by manipulating the order in which things are read 
from the CSV into the dictionary (lines 183-196); can change pub column
assumptions by modifying pubUpdate() (lines 161-165), pub total assumptions
(lines 193 and 196), and variables itemOnePub and itemTwoPub in spellCheck() 
(lines 123-150, specifically 128-9,136-7, 145).
--------------------------------------------------------------------------------
Functional summary (numbers not annotated in the script, but this is in reading
order):
(1) Get a filename from the command line (first argument), open that file as a
UTF-8. Remove header row. Make a CSV Reader object.

(2) Initialize the needed dictionaries, lists, and set. 

(3) Get destination file name (leave off .csv extension) as the second argument.

### Define functions ###
(4) Define normName function, which removes all periods and other non-
alphanumeric characters from names, ensures consistent whitespace characters,
turns all accented characters into nearest ASCII equivalents, and replaces the
name 'wm ' with 'william'. Remove 'de X'-type locutions. Returns the name.

(5) Define alphaIndex function, which first identifies where each first letter 
starts and stops in the alphabetically sorted list of names, and then does the
same for each second letter. This shrinks the search space: items with 'aa'-
starting family names are only compared to others with an 'aa' name. Runtime
benefit is close to two orders of magnitude. Returns a dictionary with two-
character string as a key and a list of two integers (start/stop) as the value.

(6) Define nullStrip(), which identifies all flagged non-canonical duplicates 
and removes them from the final list. Returns a list.

(7) Define subSCheck(), which checks for substrings. 'hicks,dan' is considered
a duplicate of canonical 'hicks,daniel j'. subSCheck() also looks for matches of
initials and matches of middle names to first names: 'akeroyd,f michael' is 
canonical version of 'akeroyd,michael'. Returns a Boolean.

(8) Define spellCheck(), which looks for family names which only show up once
with one publication and matches them to other family names at a Levenshtein
distance of <=2 and more publications, and matching items with a given name
with a matching family name, one publication, and a Levenshtein distance of <=2.
Returns a Boolean.

(9) Define isDuplicate(), which calls subSCheck() and spellCheck() on items
being compared (in one direction of comparison). Returns a Boolean.

(10) Define pubUpdate(), which takes two items, a duplicate and a canonical 
name, then updates item[1][0] and item[1][1] (the primary and secondary pub
totals). Returns the item.

(11) Define notifyUser(), which looks for possible duplicates, defined as names
where the family name matches and the given name is at a Levenshtein distance of
<=3 (catches, e.g. 'joseph' vs. 'jozef'). Returns a Boolean. 
### Functions all defined. ###

(12) Loop through each row in the Reader. Call normName() on the family and
given names. Turn the names into one string separated by a comma: 
'family,given'. Check for possible anagrams with spaces stripped out (e.g. 
'abiram' and 'abi ram') using sorted(). Remove names which consist entirely of 
initials. Check to see if the sorted name is already in the dictionary of sorted
names. If not, add it to the dictionary as a key with the full name as the value
and add the full name to the destination dictionary (with all the data) as a key
with the value a list as such: 
'Full,name': [Primary Publications integer, Secondary Publications integer, family
name  string, given name string, [given name list of first and middle names as 
separate items], Boolean value True for non-duplicate, empty string '' for the 
warning flag, list of original names [origName]]. 
If the sorted name is in the family name dictionary as a key already, then use the 
corresponding value (the full name) to update the item in the destination 
dictionary by adding the pub totals together. Also append new origName to [7] in
the list of values.

(13) Use a list comprehension to read the destination dictionary into origList of
key-value pairs turned into lists: [k, v]. Call alphaIndex() on the list to 
generate the dictionary of start/stop indices for comparison, described in (5) 
above.

(14) Add the family names of each name to a list of family names, which are then
counted for number of appearances. The family name then becomes a key and the
total number of appearances becomes a value in countDict (used in spellCheck()
in (8) above.

(15) Loop through each key in alphaDict (described in (5) above) and get
startIndex and stopIndex to identify where comparisons start and stop. For each
key, loop through all the items in the list in the range from the start index to
stop index, with each item called itemOne. Check to make sure that the Boolean
flag is not set to False, denoting a previously-identified duplicate. If it is,
move to the next item in the loop. If not, begin innermost loop, looping through
each item (itemTwo) starting after current item and until the stopIndex. Call
isDuplicate(), (9) above, first to see if itemOne is a duplicate of itemTwo. If 
isDuplicate() returns True, then change itemOne[1][5] (the Boolean flag) to
False and run pubUpdate to add itemOne's publication totals to itemTwo's. If
isDuplicate() returns False, then check to see if itemTwo is a duplicate of 
itemOne (and do the converse updating as above). If both return False, call
notifyUser(), (11) above, to see if they are possible duplicates. If 
notifyUser() returns True, then change [1][6]---the empty string--to 'Check me'
in both items, add both items to warn set for the manual check CSV, append orName
to [1][7], and continue to the next item. Otherwise, continue to the next item  
until stopIndex is reached, then move to the next item in the secondary loop and 
run the same process until each item within a starting-character-defined portion 
of the list is checked. Then move to the next item in alphaDict and start all 
over.

(16) Call nullStrip(), (6) above, to remove all items from the list identified
as duplicates of another, canonical item. 

(17) loop through all output items in FinalList, initializing
canName, the canonical name, as item[0]. For each item, loop through the list of
original names in item[1][7] and append [origName, canName] to checkList. Then
sort checkList.

(18) Open a destination CSV file as destName+'_output.csv'. 
(destName from (3) above.) Write a row of column headings. Then write the full 
canonical  family and given names as the first two columns, and [1][0] and [1][1] 
(primary  and secondary publication totals) to the third and fourth columns. Put 
the canonical names into title case using string.capwords(). Write [1][6] to the 
fifth column, indicating whether the user ought to manually check the item as a
possible duplicate. ('Check me' if yes, blank if no.)

(19) Open a warning CSV file using the same naming convention as above, but with 
'_warnings_' instead of '_output_'. Write all the names from warnList into the
CSV so that the user can see how many possible duplicates remain to be checked.

(20) Write an output CSV (encoded as UTF-8 due to data input) with column 
headings 'Orig Family','Orig Given', 'Canonical Family', 'Canonical Given'. Check
if the original name has a double comma ('X,,Y Z'), which will mess up the CSV. 
Depending on result, split on ',' or ',,'. Output CSV is 
destName + '_verif.csv'.

(21) Write destName + '_anag.csv', listing all identified anagrams (used to catch
names out of order), and write them to a csv.

(22) Close all files.
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------