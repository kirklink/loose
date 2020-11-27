# Loose Changelog


## 0.0.51
- Fix new bug in 0.0.50

## 0.0.50
- Fix reading null lists

## 0.0.49
- Remove rogue print statement

## 0.0.48
- Fix issue with querying array data

## 0.0.47
- Align analyzer dependency with similar packages

## 0.0.46
- Upgrade dependencies

## 0.0.45
- Update analyzer dependency

## 0.0.44
- Better handling of error responses

## 0.0.43
- Make fields queryable by default
- Add update field masking
- Fix reference fields accepting null

## 0.0.42
- Fix bug in update method
- Rename update method
- Throw an error when a index is required for a query

## 0.0.41
- Fixed bug when storing null in boolean field

## 0.0.40
- Allow deep nested references

## 0.0.39
- Better handling for null lists from firestore

## 0.0.38
- Fix double that looks like int from firestore

## 0.0.37
- Fix reference assignment

## 0.0.36
- Fix readonlyNull annotation on fields

## 0.0.35
- Expose raw Firestore response in document retrieval

## 0.0.34
- Fix error when auto assigning document id

## 0.0.33
- Fix error when auto assigning document id

## 0.0.32
- Fix error when auto assigning document id

## 0.0.31
- Auto assign id when creating a document

## 0.0.30
- Expose reference class

## 0.0.29
- Fix empty filter handling

## 0.0.28
- Added canQuery to nested extended classes
- Added limit and offset to queries

## 0.0.27
- Fix get request to read documents directly from firestore api

## 0.0.26
- Fix changelog :)
- Expose response errors

## 0.0.25
- Avoid return null from read when document doesn't exist

## 0.0.24
- Fixed crawling fields for main class

## 0.0.23
- Better error handling if Firestore API call fails

## 0.0.22
- Can create empty DocumentShell

## 0.0.21
- Fix returning list from single document operations

## 0.0.20
- Remove null bool in LooseResponse

## 0.0.19
- Include superclass fields to allow extending from abstract classes

## 0.0.18
- Add handling ignoreInLists for fields nested withing lists.

## 0.0.17
- Update handling ignoreIfNested on fields for new internals to allow greater reuse of document classes

## 0.0.16
- Update handling nulls for new internals

## 0.0.15
- Update queries for REST wrapper

## 0.0.14
- Reworked internals to wrap REST api instead of googleapis

## 0.0.13
- Handled nested values using default values

## 0.0.12
- Accept complete document paths with variables

## 0.0.11
- Fix empty line in generator

## 0.0.10
- Allow fields to be ignored when nested

## 0.0.9
- Better handling of deep nested documents

## 0.0.8
- Minor fix

## 0.0.7
- Better handling of deep nested documents

## 0.0.6
- Allow nesting of documents as a map within another document

## 0.0.5
- Update dependency

## 0.0.4
- Fix mapping nested lists

## 0.0.3
- Modify build process

## 0.0.2
- Use application default creds

## 0.0.1
- Initial publish
- API should not be considered stable