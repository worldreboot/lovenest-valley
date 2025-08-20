enum Terrain {
  NULL(0),
  DIRT(1),
  POND(2), // a.k.a. Water/Beach
  TILLED(3),
  GRASS(4),
  HIGH_GROUND(5),
  HIGH_GROUND_MID(6),
  SAND(7); // Beach/Sand tiles

  final int id;
  const Terrain(this.id);

  // Helper to create a Terrain enum from an ID
  static Terrain fromId(int id) {
    return Terrain.values.firstWhere(
      (e) => e.id == id,
      orElse: () => Terrain.NULL,
    );
  }
} 