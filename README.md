# Loose

- [Loose](#loose)
  * [overview](#overview)
  * [what it is](#what-it-is)
  * [what it is not](#what-it-is-not)
  * [how to use it](#how-to-use-it)
    + [annotate a class](#annotate-a-class)
    + [create a Loose instance](#create-a-loose-instance)
    + [build a query](#build-a-query)
    + [run a query](#run-a-query)

## overview
Loose is a convenience wrapper over the googleapis Firestore API that makes it simple to organize Firestore data and perform operations on the data. It requires a easy-to-use structuring of the nosql data, which tries not to get into the way but does provide some sanity for the database structure. Once the schema is defined, Loose knows how to find collections and documents without using arbitrary strings in the code.

## what it is
Currently allows CRUD and query operations although the API is not final nor stable. Loose uses code generation to handle the heavy lifting between Firestore data structures and Dart classes. 

## what it is not
It is not an ORM or a complete Firestore management solution but it does provide some ORM-esque conveniences.

## how to use it
### annotate a class
Include loose as a dependency and loose_builder as a dev dependency in the pubspec.yaml file. build_runner is also a dev dependency to run the code generation.

```yaml
...
dependencies:
  loose: '^0.0.X'
dev_dependencies:
  build_runner: any
  loose_builder: '^0.0.X'
...
```

Define the schema

```dart
import 'package:loose/schema.dart';

const database = FirestoreDatabase('PROJECT_NAME');


const animals = Collection.root('animals');
  const animal = Document(animal);
```

Create the class and assign the document from the schema to the class.

```dart
import 'package:loose/annotations.dart';

part 'animal.g.dart';

@LooseDocument(animal)
class Animal {
    @LooseField(canQuery: true)
    String name;
    DateTime createdAt;
    AnimalProps properties;

    Animal();

    static final $firestore = _$AnimalDocument();
}

@LooseMap()
class AnimalProps {
  @LooseField(canQuery: true)
  int legCount;
  String color;
}

```

The example above outlines the options that are currently available.
* `LooseField(canQuery: true)` makes the field available for queries. Since Firestore requires indexes to be defined, this helps keep fields that have been included in indexes visible.
* `static final _$AnimalDocument $firestore = _$AnimalDocument();` comes from the generated code and produces the interface to interact with the Firestore database.
 
 Don't forget to import the generated code with `part 'animal.g.dart';`, which will earn an exception if it isn't included.
 
 Loose plays nice with other generated code, such as json_serializable, so you can use the same `part` statement and reach all the generated code and have both a front-/back-end interface via json_serializable and a database interface via Loose through the same Dart model class.

 Run `pub run build_runner build` to generate the Loose code. A file called 'animal.g.dart' will be created which is automatically "appended" to the original fine with the `part` statement.

### set up the database credentials


```dart
TBC
```


### create a Loose instance

```dart
import 'package:loose/loose.dart';

...
Loose.init(); // Loose init only needs to be called once and the instance is cached.
final loose = Loose();
...
```


### build a query

```dart
final q = Query(Animal.$firestore);
q.filter(Filter.field(q.fields.properties.legCount, FieldOp.equals, 4));
```

The API for building queries is much what one would expect and there are several conveniences built in.


### run the query
When the program is ready to run the query, a connection obtained from Stanza, respecting the maxConnections configured, and the query can be executed.

```dart
final result = await loose.query(q);
for (final r in result.list) {
  print(r.entity.name);
}
```

