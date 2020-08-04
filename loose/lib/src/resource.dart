abstract class Resource {

  final Resource parent;
  final String name;
  final children = const <Resource>[]; 

  const Resource(this.parent, [this.name = '']);
  
  const Resource.root(this.name, [this.parent]);
  
  bool get isAtRoot => parent == null;

  String get path => '${parent.path}/$name';


}
