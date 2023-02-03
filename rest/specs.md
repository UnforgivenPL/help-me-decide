# REST API for HelpMeDecide

the purpose of this document is to list all the possible REST endpoints and data structures

this directory also provides a somewhat reference implementation that uses Sinatra

## main principles

datasets and their definitions are expected to be stored separately from questions asked
authentication and authorisation is done via access tokens; implementations are free to relax or strengthen this 

429 is returned on any request if the authenticated user has run out of available requests
451 is returned on any request if the content is subject to an investigation of being illegal
401 and 403 are also used

## data format

the accepted format data format is JSON, both for request and response

requests that have body expect to have named parts (so a body must be a map)

# datasets

datasets are immutable

## `GET /dataset`

200 an array of dataset ids available

## `GET /dataset/{id}`

200 when successful; result has `dataset` of a given id, its `definition`, and available `strategies` (an non-empty array of strategy names available, with the first one being the default)
404 when there is no dataset of the given id

## `POST /dataset`

body **must** contain a `dataset` that is a proper dataset
(not yet: body **may** contain a `definition` that is a proper dataset definition; a default one will be guessed if needed)
creates a new dataset
200 and the id of the newly created dataset if successful
400 when the dataset has an error or there is no dataset
409 when identical dataset already exists
422 when the dataset contains two or more items with different ids, but the same features (response will be json with an array of whatever ids are duplicates)
(not yet: 409 when the definition does not match the dataset)

## `DELETE /dataset/{id}`

removes an existing dataset
204 when successful
404 when the dataset was not found

# questions

this is intended to provide available questions for datasets
when previously asked questions lead to exactly one result, there will be no more future questions to be asked

## `GET /question/{id}(/{strategy})`

request parameters should be all previously asked questions (question=answer&question=answer...)
200 when successful; result has `question` with the next question (if any), `answers` with all answers so far, a `dataset` with whatever is the dataset at this stage and its `definition`, and available `strategies`
204 when dataset is empty (no data matches)
400 when the strategy is incorrect or data is incorrect
404 when dataset of the given id not found
409 when the given answers do not fit the dataset

## `PUT /questions/{id}`

request parameters should be all previously asked questions (question=answer&question=answer...)
200 when successful; result has `questions` with all available next questions (if any), `answers` with all answers so far, a `dataset` with whatever is the dataset at this stage and its `definition`, and available `strategies`
204 when no questions can be asked
400 when the strategy is incorrect or data is incorrect
404 when dataset of the given id not found
409 when the given answers do not fit the dataset
