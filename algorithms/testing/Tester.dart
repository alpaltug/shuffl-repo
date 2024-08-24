import "dart:math";

//import "dart:collection";

import "package:collection/collection.dart";

import "Car.dart";
import "Person.dart";

int dim = 1000; //how many nodes? can modify globally from here

var rand = Random(); //random number Dart generator
var school_library = ["UC Berkeley", "Contra Costa", "Stanford", "UCSB", "UCLA", "Diablo Valley", "Sierra CC", "Santa Barbara CC", "Westmont College", "Laguna Blanca School"];
//above: schools passengers come from
//below: our map as a weighted adjacency list (could convert to distance array if needed)
//var ourMap =  List<List>.generate(dim, (i) => List<List>.generate(dim, (j) => null, growable: true), growable: false);

//var ourMap = List.generate(dim, (i) => List.generate(dim, (j) => i + j));

var ourMap = [];

//var ourMap = List<List<List<int>>>;

//var adMap = [];

//NOT NECESSARY, SHOULD SUPPORT REPRIORITIZING
/*class PQueue {//for Djikstra's
  Queue ourQueue = new Queue();

  PQueue();
}*/

//var testMap = [[(1, 3), (3, 1)], [(0, 3), (4, 2), (2, 4)], [(1, 4), (3, 6)], [(0, 1), (2, 6), (4, 2), (5, 6)], [(1, 2), (3, 2), (5, 3)], [(3, 6), (4, 3)]];

var testMap = [
  [
    [1, 3],
    [3, 1]
  ],
  [
    [0, 3],
    [4, 2],
    [2, 4]
  ],
  [
    [1, 4],
    [3, 6]
  ],
  [
    [0, 1],
    [2, 6],
    [4, 2],
    [5, 6]
  ],
  [
    [1, 2],
    [3, 2],
    [5, 3]
  ],
  [
    [3, 6],
    [4, 3]
  ]
];

Person generate_passenger(){
  //randomly generate: pickup, dropoff (sufficiently far away), age, sex, school, school/age/sex/walking preferences
  //age design: tend to be in 20s, with variance from 18 to 50
  //formula: rand(0, 10) + 18 + max(0, rand(0, 200) - 160)
  int age = rand.nextInt(11) + 18 + max(0, rand.nextInt(200) - 160);
  //age preferences: take base age
  //min age: max(18, age - age/2*rand(0, 1))
  int minAge = max(18, age - (age~/2) * rand.nextInt(2));
  if(rand.nextInt(2) > 0){
    minAge = 18;
  }
  //max age: min(58, age + age/2*rand(0, 1))
  int maxAge = min(58, age + (age~/2) * rand.nextInt(2));
  if(rand.nextInt(2) > 0){
    maxAge = 58;
  }
  int pick = rand.nextInt(dim);//pickup
  int walk = rand.nextInt(10);//max-walking preference
  int male = rand.nextInt(2);
  int sex_preference = rand.nextInt(2);
  int school = rand.nextInt(10);
  int drop = 0; //will reset it
  var schools = [];
  if(rand.nextInt(2) == 1){
    for (int i = 0; i < 10; i++){
      schools.add(school_library[i]);
    }
  } else {
    schools.add(school_library[school]);
    for (int i = 0; i < 10; i++){
      if(i != school && rand.nextInt(10) == 7){
        schools.add(school_library[i]);
      }
    }
  }
  //assert(dim > walk);//could infinite loop otherwise//IGNORE
  int antiLoop = 0;
  int probDim = 28 * dim;
  while (antiLoop < probDim){
    drop = rand.nextInt(dim); //dropoff
    if(dist(pick, drop) > walk){
      break;
    }
    antiLoop++;
  }
  assert(antiLoop < probDim);//test case valid?
  Person bob = new Person(pick, drop, (male != 0), school_library[school], age, minAge, maxAge, (sex_preference != 0), schools, walk);
  return bob;
}

//Setup for Djikstra's

int compList(List<int> a, List<int> b){
  if (a[0] > b[0]){
    return 1;
  } else if (a[0] < b[0]){
    return -1;
  }
  return 0;
}

List<int> dists = [];

var prev = [];

Map lookup = {
  -1:-1
};

var look = [];

bool update(int u, int v, int w){
  bool updated = false;
  if (dists[u] + w < dists[v]){
    prev[v] = u;
    updated = true;
  }
  dists[v] = min(dists[v], dists[u] + w);
  return updated;
}

int d(a, b){
  return min(dist(a, b), dist(b, a));
}

int dist(int a, int b){//Calculate distance between two nodes via Djikstra's
  if(a == b){
    return 0;
  }
  dists = [];
  prev = [];
  for (int i = 0; i < dim; i++){
    dists.add(double.maxFinite.toInt());
    prev.add(Null);
    //adMap.add();
  }
  dists[a] = 0;
  HeapPriorityQueue checkers = HeapPriorityQueue();//PRIMARY ISSUE AT MOMENT: comparator
  checkers.add(0);
  lookup[0] = a;
  while (!checkers.isEmpty){
    int extract = checkers.removeFirst();
    //int n = extract[0];
    int u = lookup[extract];
    /*if (u == b){
      int d = u;
      while(d != s){

      }
    }*///not needed
    for (int i = 0; i < ourMap[u].length; i++){
      int v = ourMap[u][i][0];//node
      int w = ourMap[u][i][1];//distance
      if (update(u, v, w)){
        checkers.add(dists[v]);
        lookup[dists[v]] = v;
      }
      
    }
  }
  return dists[b];
  //return 100;
}
//ideas: list of primes, randomly
//generate random points, then randomly connect them until graph fully connected, feed into adjacency list
void generateMap() {
  //Here we generate our map
  ourMap =[];
  for(int a = 0; a < dim; a++){
    var eList = [];
    ourMap.add(eList);
  }
  for(int i = 0; i < dim; i++){
    for(int j = i + 1; j < dim; j++){
      if(i == j){
        //ourMap[i][j] = (j, 0);
        //ourMap[i].add([j, 0]);
        //ourMap[j].add([i, 0]);
      }/*(j + 1) % (i + 1) == 0 */
      else if (i == 0){
        //ourMap[i][j] = (j, rand.nextInt(100));
        int dis = rand.nextInt(100) + 1;
        ourMap[i].add([j, dis]);
        ourMap[j].add([i, dis]);
      }
      else if (rand.nextInt(100) >= 80){
        int dis = rand.nextInt(30) + 1;
        ourMap[i].add([j, dis]);
        ourMap[j].add([i, dis]);
      }
    }
  }
}

int smallD = 40;

int tinyD = 40;

void generateTinyMap() {
  ourMap = [];
  //Here we generate our map
  for (int a = 0; a < tinyD; a++) {
    var eList = [];
    ourMap.add(eList);
  }
  for (int i = 0; i < tinyD; i++) {
    for (int j = i; j < tinyD; j++) {
      if (i == j) {
        //ourMap[i][j] = (j, 0);
        //ourMap[i].add([j, 0]);
      } /*(j + 1) % (i + 1) == 0 */
      else if (i == 0) {
        //ourMap[i][j] = (j, rand.nextInt(100));
        int dis = rand.nextInt(100);
        ourMap[i].add([j, dis]);
        ourMap[j].add([i, dis]);
      } else if (rand.nextInt(100) >= 90) {
        int dis = rand.nextInt(100);
        ourMap[i].add([j, dis]);
        ourMap[j].add([i, dis]);
      }
    }
  }
}

void generateLargeMap() {
  ourMap = [];
  //Here we generate our map
  for (int a = 0; a < 100; a++) {
    var eList = [];
    ourMap.add(eList);
  }
  for (int i = 0; i < 100; i++) {
    for (int j = i; j < 100; j++) {
      if (i == j) {
        //ourMap[i][j] = (j, 0);
        //ourMap[i].add([j, 0]);
      } /*(j + 1) % (i + 1) == 0 */
      else {
        //ourMap[i][j] = (j, rand.nextInt(100));
        int dis = rand.nextInt(100);
        ourMap[i].add([j, dis]);
        ourMap[j].add([i, dis]);
      }
    }
  }
}

void generateSmallMap() {
  ourMap = [];
  //Here we generate our map
  for (int a = 0; a < smallD; a++) {
    var eList = [];
    ourMap.add(eList);
  }
  for (int i = 0; i < smallD; i++) {
    for (int j = i; j < smallD; j++) {
      if (i == j) {
        //ourMap[i][j] = (j, 0);
        //ourMap[i].add([j, 0]);
      } /*(j + 1) % (i + 1) == 0 */
      else {
        //ourMap[i][j] = (j, rand.nextInt(100));
        int dis = rand.nextInt(100);
        ourMap[i].add([j, dis]);
        ourMap[j].add([i, dis]);
      }
    }
  }
}

void main() {
  var ride_requests = [];
  var fleet = [];
  for (int i = 0; i < 10; i++){ //start with a fleet of 10 cars
    Car car = new Car(i, 0);
    fleet.add(car);
  }
  var bob_schools = ["UC Berkeley"];//placeholder person to get rid of later
  Person bob = new Person(0, 20, true, "UC Berkeley", 20, 18, 25, false, bob_schools, 5);
  ride_requests.add(bob);
  ride_requests.remove(bob);
  //create our map
  generateMap();
  int time = 0;
  while (time < 1000000 || !ride_requests.isEmpty){//version 1: just scan for closest available car
    if(rand.nextInt(100) > 80){
      Person p = generate_passenger();
      int m = double.maxFinite.toInt();
      int n = 10;
      int count = 0;
      for (Car c in fleet) {
        int o =  d(p.getLocation(), c.getLoc());
        if(o < m) {
          m = o;
          n = count;
        }
        count++;
      }
    }
  }
  /*
  generateSmallMap();
  //ourMap = testMap;
  //print(dist(3, 5));
  print(dist(1, 4));
  print(dist(0, 2));
  print(dist(0, 3));
  print("Next two");
  print(dist(2, 3));
  print(dist(3, 2));
  print("Next three should be same");
  print(dist(0, 4));
  print(dist(4, 0));
  print(dist(0, 4));
  print(dist(37, 35));
  print(dist(35, 37));
  */
  //ourMap = testMap;
  //print(dist(3, 5));
  /* 
  Create an nxn (maybe 1000x1000) nested 2-dimensional edge "distance" matrix
  We need a mechanism to somewhat represent "neighborhoods" of connected nodes, with the graph being fully connected
  Within neighborhoods interconnection should be more common. But, paths should be sparse (BUT EXIST) between different
  neighborhoods. */
  //Given a time period, start generating random requests across map
  /*
  We have a given period of time for the simulation to run. The lengthier, the better for recording results.

  Essentially, at random locations, people start requesting rides. Cars travel to pick them up, or group them and have them walk. */
  //also implement a Djikstra's algorithm for computing shortest paths
}