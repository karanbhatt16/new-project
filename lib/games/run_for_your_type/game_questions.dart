import 'game_models.dart';

/// Questions for the "Run For Your Type" game.
/// 
/// Questions are categorized into:
/// 1. "About Me" - Describe yourself
/// 2. "Preferred Match" - What you want in a partner
/// 
/// Some questions are gender-specific.

// ============================================================
// ABOUT ME QUESTIONS - Users describe themselves
// ============================================================

const List<GameQuestion> aboutMeQuestionsMale = [
  GameQuestion(
    id: 'am_m_1',
    text: 'Do you wear specs/glasses?',
    category: 'about_me',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'am_m_2',
    text: 'Do you have a female best friend?',
    category: 'about_me',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'am_m_3',
    text: 'Are you taller than 5\'10"?',
    category: 'about_me',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'am_m_4',
    text: 'Do you like cooking?',
    category: 'about_me',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'am_m_5',
    text: 'Are you an introvert?',
    category: 'about_me',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'am_m_6',
    text: 'Do you play sports regularly?',
    category: 'about_me',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'am_m_7',
    text: 'Do you have a beard/stubble?',
    category: 'about_me',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'am_m_8',
    text: 'Are you a night owl?',
    category: 'about_me',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'am_m_9',
    text: 'Do you like romantic movies?',
    category: 'about_me',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'am_m_10',
    text: 'Can you play a musical instrument?',
    category: 'about_me',
    forGender: 'male',
  ),
];

const List<GameQuestion> aboutMeQuestionsFemale = [
  GameQuestion(
    id: 'am_f_1',
    text: 'Do you wear specs/glasses?',
    category: 'about_me',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'am_f_2',
    text: 'Do you have a male best friend?',
    category: 'about_me',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'am_f_3',
    text: 'Are you taller than 5\'4"?',
    category: 'about_me',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'am_f_4',
    text: 'Do you like cooking?',
    category: 'about_me',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'am_f_5',
    text: 'Are you an introvert?',
    category: 'about_me',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'am_f_6',
    text: 'Do you enjoy shopping?',
    category: 'about_me',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'am_f_7',
    text: 'Do you wear traditional outfits often?',
    category: 'about_me',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'am_f_8',
    text: 'Are you a night owl?',
    category: 'about_me',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'am_f_9',
    text: 'Do you like romantic movies?',
    category: 'about_me',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'am_f_10',
    text: 'Do you enjoy dancing?',
    category: 'about_me',
    forGender: 'female',
  ),
];

// ============================================================
// PREFERRED MATCH QUESTIONS - What users want in a partner
// ============================================================

/// Questions for males about their preferred female match
const List<GameQuestion> preferredMatchQuestionsMale = [
  GameQuestion(
    id: 'pm_m_1',
    text: 'Do you like girls with specs/glasses?',
    category: 'preferred_match',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'pm_m_2',
    text: 'Are you okay with a girl having a male best friend?',
    category: 'preferred_match',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'pm_m_3',
    text: 'Do you prefer tall girls (5\'4" or above)?',
    category: 'preferred_match',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'pm_m_4',
    text: 'Do you want someone who can cook?',
    category: 'preferred_match',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'pm_m_5',
    text: 'Do you prefer introverted girls?',
    category: 'preferred_match',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'pm_m_6',
    text: 'Do you like girls who enjoy shopping?',
    category: 'preferred_match',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'pm_m_7',
    text: 'Do you like girls in traditional outfits?',
    category: 'preferred_match',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'pm_m_8',
    text: 'Do you prefer someone who is a night owl?',
    category: 'preferred_match',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'pm_m_9',
    text: 'Do you want someone who loves romantic movies?',
    category: 'preferred_match',
    forGender: 'male',
  ),
  GameQuestion(
    id: 'pm_m_10',
    text: 'Do you like girls who enjoy dancing?',
    category: 'preferred_match',
    forGender: 'male',
  ),
];

/// Questions for females about their preferred male match
const List<GameQuestion> preferredMatchQuestionsFemale = [
  GameQuestion(
    id: 'pm_f_1',
    text: 'Do you like guys with specs/glasses?',
    category: 'preferred_match',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'pm_f_2',
    text: 'Are you okay with a guy having a female best friend?',
    category: 'preferred_match',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'pm_f_3',
    text: 'Do you prefer tall guys (5\'10" or above)?',
    category: 'preferred_match',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'pm_f_4',
    text: 'Do you want someone who can cook?',
    category: 'preferred_match',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'pm_f_5',
    text: 'Do you prefer introverted guys?',
    category: 'preferred_match',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'pm_f_6',
    text: 'Do you like guys who play sports?',
    category: 'preferred_match',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'pm_f_7',
    text: 'Do you like guys with a beard/stubble?',
    category: 'preferred_match',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'pm_f_8',
    text: 'Do you prefer someone who is a night owl?',
    category: 'preferred_match',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'pm_f_9',
    text: 'Do you want someone who loves romantic movies?',
    category: 'preferred_match',
    forGender: 'female',
  ),
  GameQuestion(
    id: 'pm_f_10',
    text: 'Do you like guys who can play musical instruments?',
    category: 'preferred_match',
    forGender: 'female',
  ),
];

/// Question mapping for calculating compatibility.
/// Maps a preferred_match question to the corresponding about_me question of the opposite gender.
/// 
/// Example: Male's "pm_m_1" (likes girls with specs) maps to Female's "am_f_1" (wears specs)
const Map<String, String> questionMappingMaleToFemale = {
  'pm_m_1': 'am_f_1',   // specs preference -> has specs
  'pm_m_2': 'am_f_2',   // okay with male bestfriend -> has male bestfriend
  'pm_m_3': 'am_f_3',   // prefers tall -> is tall
  'pm_m_4': 'am_f_4',   // wants cook -> can cook
  'pm_m_5': 'am_f_5',   // prefers introvert -> is introvert
  'pm_m_6': 'am_f_6',   // likes shopping girls -> enjoys shopping
  'pm_m_7': 'am_f_7',   // likes traditional -> wears traditional
  'pm_m_8': 'am_f_8',   // prefers night owl -> is night owl
  'pm_m_9': 'am_f_9',   // wants romantic movie lover -> likes romantic movies
  'pm_m_10': 'am_f_10', // likes dancing girls -> enjoys dancing
};

const Map<String, String> questionMappingFemaleToMale = {
  'pm_f_1': 'am_m_1',   // specs preference -> has specs
  'pm_f_2': 'am_m_2',   // okay with female bestfriend -> has female bestfriend
  'pm_f_3': 'am_m_3',   // prefers tall -> is tall
  'pm_f_4': 'am_m_4',   // wants cook -> can cook
  'pm_f_5': 'am_m_5',   // prefers introvert -> is introvert
  'pm_f_6': 'am_m_6',   // likes sporty guys -> plays sports
  'pm_f_7': 'am_m_7',   // likes beard -> has beard
  'pm_f_8': 'am_m_8',   // prefers night owl -> is night owl
  'pm_f_9': 'am_m_9',   // wants romantic movie lover -> likes romantic movies
  'pm_f_10': 'am_m_10', // likes musicians -> plays instrument
};

/// Helper to get questions based on gender.
List<GameQuestion> getAboutMeQuestions(String gender) {
  return gender.toLowerCase() == 'male' 
      ? aboutMeQuestionsMale 
      : aboutMeQuestionsFemale;
}

List<GameQuestion> getPreferredMatchQuestions(String gender) {
  return gender.toLowerCase() == 'male' 
      ? preferredMatchQuestionsMale 
      : preferredMatchQuestionsFemale;
}

Map<String, String> getQuestionMapping(String myGender) {
  return myGender.toLowerCase() == 'male'
      ? questionMappingMaleToFemale
      : questionMappingFemaleToMale;
}
