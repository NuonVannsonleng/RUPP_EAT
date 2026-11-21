class Classroom {
  Classroom(this.id, this.name, this.type);
  final String id;
  final String name;
  final String type;
}

class Floor {
  Floor(this.id, this.number, this.label, this.classrooms);
  final String id;
  final int number;
  final String label;
  final List<Classroom> classrooms;
}

class Building {
  Building(this.id, this.name, this.code, this.floors);
  final String id;
  final String name;
  final String code;
  final List<Floor> floors;
}

class Faculty {
  Faculty(this.id, this.name, this.code, this.buildings);
  final String id;
  final String name;
  final String code;
  final List<Building> buildings;

  /// Parses GET /api/campus/locations
  static List<Faculty> listFromJson(List data) => data.map((f) {
        final fm = (f as Map).cast<String, dynamic>();
        return Faculty(
          fm['id'],
          fm['name'],
          fm['code'],
          (fm['buildings'] as List).map((b) {
            final bm = (b as Map).cast<String, dynamic>();
            return Building(
              bm['id'],
              bm['name'],
              bm['code'],
              (bm['floors'] as List).map((fl) {
                final flm = (fl as Map).cast<String, dynamic>();
                return Floor(
                  flm['id'],
                  flm['number'],
                  flm['label'],
                  (flm['classrooms'] as List).map((c) {
                    final cm = (c as Map).cast<String, dynamic>();
                    return Classroom(cm['id'], cm['name'], cm['type']);
                  }).toList(),
                );
              }).toList(),
            );
          }).toList(),
        );
      }).toList();
}
