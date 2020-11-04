# Loose Builder Changelog

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