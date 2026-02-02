bool isValidNitjEmail(String email) {
  final trimmed = email.trim().toLowerCase();

  // Expected: name.branch.year@nitj.ac.in
  // Example: rahul.cse.23@nitj.ac.in
  final regex = RegExp(r'^[a-z]+\.[a-z]+\.[0-9]{2,4}@nitj\.ac\.in$');

  return regex.hasMatch(trimmed);
}
