#! python3
# This script checks for differences in the first two columns of two CSV files and creates a new CSV with all differences listed---i.e. the names that appear in one file but not the other. Controls for false positives.

import csv, os, sys, time
from datetime import datetime

start = time.perf_counter()

###################################################
# Get filenames from command line and assign to file1 and file2. Get output file (without .csv) and assign to outName.
file1 = sys.argv[1]
file2 = sys.argv[2]
outName = sys.argv[3]

# Make file 1 CSV into a list
origFile1 = open(file1, 'r', encoding ='utf8')
origReader1 = csv.reader(origFile1)
origList1 = list(origReader1)
count1 = sum(1 for row in origList1)
print(count1)

# Make file 2 CSV into a list
origFile2 = open(file2, 'r', encoding ='utf8')
origReader2 = csv.reader(origFile2)
origList2 = list(origReader2)
count2 = sum(1 for row in origList2)
print(count2)
###################################################
def setMaker(someList,someSet):
	for item in someList:
		n1,n2,v1,v2 = item
		name = (n1 + ',' + n2)
		someSet.add(name)
	return someSet
###################################################
# Figure out which file is longer.
if count1 > count2:
	bigList = origList1
	smallList = origList2
elif count1 == count2:
	print('They\'re the same file, idiot.')
	origFile1.close()
	origFile2.close()
	sys.exit()
else:
	bigList = origList2
	smallList = origList1

# Read each CSV's names into a set of strings.
bigSet = set()
smallSet = set()
setMaker(bigList,bigSet)
setMaker(smallList,smallSet)

# Get the difference of the two sets.
outputSet = bigSet.difference(smallSet)
print(outputSet)
###################################################
# write the list to the output file
destFile = open(outName + '_qcShortList_' + datetime.now().strftime('%Y%m%d%H%M') + '.csv', 'w', newline='')
outputWriter = csv.writer(destFile)
outputWriter.writerow(['Family','Given'])

for item in outputSet:
    outputWriter.writerow([item.split(',')[0],item.split(',')[1]])

destFile.close()
origFile1.close()
origFile2.close()
end = time.perf_counter()
perfTime = (end - start)
print(perfTime)