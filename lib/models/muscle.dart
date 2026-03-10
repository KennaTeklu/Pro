class MuscleGroup {
  final String name;
  final String display;
  final int restDays;
  final String category;   // 'major', 'longevity', 'hands', 'feet'
  final String? agingRisk; // 'high', 'medium', 'low'

  MuscleGroup({
    required this.name,
    required this.display,
    required this.restDays,
    required this.category,
    this.agingRisk,
  });
}

class MuscleDatabase {
  static final List<MuscleGroup> major = [
    MuscleGroup(name: "quads", display: "Quadriceps", restDays: 3, category: "lower"),
    MuscleGroup(name: "hamstrings", display: "Hamstrings", restDays: 3, category: "lower"),
    MuscleGroup(name: "glutes", display: "Glutes", restDays: 2, category: "lower"),
    MuscleGroup(name: "chest", display: "Chest", restDays: 2, category: "upper"),
    MuscleGroup(name: "back", display: "Back", restDays: 2, category: "upper"),
    MuscleGroup(name: "shoulders", display: "Shoulders", restDays: 2, category: "upper"),
    MuscleGroup(name: "biceps", display: "Biceps", restDays: 2, category: "arms"),
    MuscleGroup(name: "triceps", display: "Triceps", restDays: 2, category: "arms"),
    MuscleGroup(name: "calves", display: "Calves", restDays: 2, category: "lower"),
    MuscleGroup(name: "core", display: "Core", restDays: 1, category: "core"),
    MuscleGroup(name: "forearms", display: "Forearms", restDays: 2, category: "arms"),
    MuscleGroup(name: "traps", display: "Traps", restDays: 2, category: "upper"),
    MuscleGroup(name: "lats", display: "Latissimus Dorsi", restDays: 2, category: "upper"),
    MuscleGroup(name: "rear_delts", display: "Rear Deltoids", restDays: 2, category: "upper"),
    MuscleGroup(name: "obliques", display: "Obliques", restDays: 2, category: "core"),
    MuscleGroup(name: "hip_flexors", display: "Hip Flexors", restDays: 2, category: "lower"),
    MuscleGroup(name: "adductors", display: "Adductors", restDays: 3, category: "lower"),
    MuscleGroup(name: "abductors", display: "Abductors", restDays: 2, category: "lower"),
    MuscleGroup(name: "erectors", display: "Erector Spinae", restDays: 3, category: "core"),
    MuscleGroup(name: "serratus", display: "Serratus Anterior", restDays: 2, category: "upper"),
  ];

  static final List<MuscleGroup> longevity = [
    MuscleGroup(name: "neck", display: "Neck", restDays: 3, category: "longevity", agingRisk: "high"),
    MuscleGroup(name: "deep_neck", display: "Deep Neck Flexors", restDays: 2, category: "longevity", agingRisk: "high"),
    MuscleGroup(name: "levator_scap", display: "Levator Scapulae", restDays: 2, category: "longevity", agingRisk: "medium"),
    MuscleGroup(name: "rhomboids", display: "Rhomboids", restDays: 2, category: "longevity", agingRisk: "medium"),
    MuscleGroup(name: "teres", display: "Teres Major/Minor", restDays: 3, category: "longevity", agingRisk: "medium"),
    MuscleGroup(name: "infraspinatus", display: "Infraspinatus", restDays: 3, category: "longevity", agingRisk: "high"),
    MuscleGroup(name: "supraspinatus", display: "Supraspinatus", restDays: 3, category: "longevity", agingRisk: "high"),
    MuscleGroup(name: "subscapularis", display: "Subscapularis", restDays: 3, category: "longevity", agingRisk: "high"),
    MuscleGroup(name: "brachialis", display: "Brachialis", restDays: 2, category: "longevity", agingRisk: "low"),
    MuscleGroup(name: "brachioradialis", display: "Brachioradialis", restDays: 2, category: "longevity", agingRisk: "low"),
    MuscleGroup(name: "anconeus", display: "Anconeus", restDays: 2, category: "longevity", agingRisk: "medium"),
    MuscleGroup(name: "supinator", display: "Supinator", restDays: 2, category: "longevity", agingRisk: "medium"),
    MuscleGroup(name: "pronator", display: "Pronators", restDays: 2, category: "longevity", agingRisk: "medium"),
    MuscleGroup(name: "pec_minor", display: "Pectoralis Minor", restDays: 2, category: "longevity", agingRisk: "medium"),
    MuscleGroup(name: "coracobrach", display: "Coracobrachialis", restDays: 2, category: "longevity", agingRisk: "low"),
    MuscleGroup(name: "popliteus", display: "Popliteus", restDays: 3, category: "longevity", agingRisk: "high"),
    MuscleGroup(name: "tibialis", display: "Tibialis Anterior", restDays: 2, category: "longevity", agingRisk: "medium"),
    MuscleGroup(name: "soleus", display: "Soleus", restDays: 2, category: "longevity", agingRisk: "medium"),
    MuscleGroup(name: "peroneus_tertius", display: "Peroneus Tertius", restDays: 2, category: "longevity", agingRisk: "high"),
    MuscleGroup(name: "articularis_genus", display: "Articularis Genus", restDays: 2, category: "longevity", agingRisk: "high"),
    MuscleGroup(name: "multifidus", display: "Multifidus", restDays: 2, category: "longevity", agingRisk: "high"),
    MuscleGroup(name: "transverse", display: "Transverse Abdominis", restDays: 1, category: "longevity", agingRisk: "high"),
    MuscleGroup(name: "quadratus_plantae", display: "Quadratus Plantae", restDays: 2, category: "longevity", agingRisk: "medium"),
  ];

  static final List<MuscleGroup> hands = [
    MuscleGroup(name: "hand_lumbricals", display: "Hand Lumbricals", restDays: 1, category: "hands", agingRisk: "high"),
    MuscleGroup(name: "hand_interossei", display: "Hand Interossei", restDays: 1, category: "hands", agingRisk: "high"),
    MuscleGroup(name: "thenar", display: "Thenar/Hypothenar", restDays: 1, category: "hands", agingRisk: "high"),
  ];

  static final List<MuscleGroup> feet = [
    MuscleGroup(name: "foot_intrinsics", display: "Foot Intrinsics", restDays: 1, category: "feet", agingRisk: "high"),
    MuscleGroup(name: "foot_interossei", display: "Foot Interossei", restDays: 1, category: "feet", agingRisk: "high"),
    MuscleGroup(name: "abductor_hallucis", display: "Abductor Hallucis", restDays: 2, category: "feet", agingRisk: "medium"),
    MuscleGroup(name: "flexor_brevis", display: "Flexor Digitorum Brevis", restDays: 2, category: "feet", agingRisk: "medium"),
  ];

  static List<MuscleGroup> get all => [...major, ...longevity, ...hands, ...feet];

  static MuscleGroup? byName(String name) {
    try {
      return all.firstWhere((m) => m.name == name);
    } catch (e) {
      return null;
    }
  }
}
