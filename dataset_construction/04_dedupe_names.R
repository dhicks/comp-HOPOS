## This is just a wrapper around the Python scripts for de-duplicating names
## Included so the whole sequences can be executed by "run the R scripts in order"

## See `04_readme.txt` for information about these scripts

## Notable Python dependencies:  Levenshtein
## Try `pip install python-Levenshtein``

## Use the first line to point system() to the correct Python
# system('alias python=/Users/danhicks/anaconda3/bin/python;
#        python 04_dupe_remove.py test.csv testing')

system('alias python=/Users/danhicks/anaconda3/bin/python;
       python 04_dupe_remove.py ../data/03_names.csv ../data/04_names')

