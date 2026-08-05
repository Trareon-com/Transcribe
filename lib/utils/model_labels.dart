/// Label UI generik untuk model — nama model TIDAK boleh terekspos ke user.
String modelDisplayLabel(String id) {
  return switch (id) {
    'tiny' => 'Ringan',
    'base' => 'Cepat',
    'small' => 'Sedang',
    'medium' => 'Tinggi',
    'large-v3-turbo' => 'Akurat',
    'large-v3-turbo-q5' => 'Akurat (disarankan)',
    _ => 'Model terpasang',
  };
}
