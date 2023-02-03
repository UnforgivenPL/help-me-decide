# purpose

the purpose of this document is to hold a rough specs of the entire system

# dataset

a raw dataset is shown (in yaml) in the test directory

## guessing features

a dataset should be enough by itself, provided it is well defined (i.e. each feature has a consistent type across all things)

the engine is capable of guessing the features and providing a list of them: `Engine.extract_features(dataset)`

## feature definitions

currently the following features are supported:
* :set (a collection of non-repeating values from a predefined set of all available values)
* :value (a single value from a predefined set of all available values)
* :flag (can be set or unset, does not have any value by itself)
* :number
* :text (any free-form text)

features should be provided with the metadata
if they are absent, the following assumptions are made:
* if any of the values is an array, feature is considered a set
* if all values are the same, feature is a flag
* if all values are numbers, feature is a number
* otherwise, a feature is a single value and all encountered values are considered a set of possible values

note that it is thus impossible for a feature to be guessed as a free text

# selection narrowing

each question narrows the dataset to only those elements that match the answer

for a dataset a map of questions can be created: key in the map is the feature to be asked, with value of the map being another map of possible answer and dataset element ids (always in an array) matching the selection

possible answers that return all dataset ids are not included; questions with no answers are also omitted