import 'dart:math';

import 'game_models.dart';

const wouldYouRatherQuestions = <WouldYouRatherQuestion>[
  // Superpowers & Fantasy (1-15)
  WouldYouRatherQuestion(id: 'q1', optionA: 'Have the ability to fly', optionB: 'Be invisible', category: 'superpowers'),
  WouldYouRatherQuestion(id: 'q2', optionA: 'Read minds', optionB: 'Control time', category: 'superpowers'),
  WouldYouRatherQuestion(id: 'q3', optionA: 'Have super strength', optionB: 'Have super speed', category: 'superpowers'),
  WouldYouRatherQuestion(id: 'q4', optionA: 'Breathe underwater', optionB: 'Survive in space', category: 'superpowers'),
  WouldYouRatherQuestion(id: 'q5', optionA: 'Talk to animals', optionB: 'Speak all human languages', category: 'superpowers'),
  WouldYouRatherQuestion(id: 'q6', optionA: 'Have a photographic memory', optionB: 'Have genius-level IQ', category: 'superpowers'),
  WouldYouRatherQuestion(id: 'q7', optionA: 'Control fire', optionB: 'Control water', category: 'superpowers'),
  WouldYouRatherQuestion(id: 'q8', optionA: 'Teleport anywhere', optionB: 'Time travel', category: 'superpowers'),
  WouldYouRatherQuestion(id: 'q9', optionA: 'Never need sleep', optionB: 'Never need food', category: 'superpowers'),
  WouldYouRatherQuestion(id: 'q10', optionA: 'Be a vampire', optionB: 'Be a werewolf', category: 'superpowers'),
  WouldYouRatherQuestion(id: 'q11', optionA: 'Live in the Harry Potter universe', optionB: 'Live in the Marvel universe', category: 'superpowers'),
  WouldYouRatherQuestion(id: 'q12', optionA: 'Have a dragon as a pet', optionB: 'Have a phoenix as a pet', category: 'superpowers'),
  WouldYouRatherQuestion(id: 'q13', optionA: 'Be able to fly but only 2 feet off the ground', optionB: 'Be invisible but only when no one is looking', category: 'superpowers'),
  WouldYouRatherQuestion(id: 'q14', optionA: 'Have X-ray vision', optionB: 'Have night vision', category: 'superpowers'),
  WouldYouRatherQuestion(id: 'q15', optionA: 'Control the weather', optionB: 'Control technology with your mind', category: 'superpowers'),

  // Lifestyle & Preferences (16-35)
  WouldYouRatherQuestion(id: 'q16', optionA: 'Always be 10 minutes late', optionB: 'Always be 20 minutes early', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q17', optionA: 'Live in the city', optionB: 'Live in the countryside', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q18', optionA: 'Be rich but alone', optionB: 'Be poor but surrounded by loved ones', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q19', optionA: 'Work your dream job for low pay', optionB: 'Work a boring job for high pay', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q20', optionA: 'Live without music', optionB: 'Live without movies', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q21', optionA: 'Be famous', optionB: 'Be powerful behind the scenes', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q22', optionA: 'Have a personal chef', optionB: 'Have a personal driver', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q23', optionA: 'Always have to tell the truth', optionB: 'Always have to lie', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q24', optionA: 'Be extremely lucky', optionB: 'Be extremely talented', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q25', optionA: 'Have a rewind button for life', optionB: 'Have a pause button for life', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q26', optionA: 'Know how you will die', optionB: 'Know when you will die', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q27', optionA: 'Be able to see 10 years into the future', optionB: 'Be able to change 1 decision in your past', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q28', optionA: 'Have free WiFi everywhere', optionB: 'Have free coffee everywhere', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q29', optionA: 'Always be overdressed', optionB: 'Always be underdressed', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q30', optionA: 'Have no responsibilities for a month', optionB: 'Have unlimited money for a day', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q31', optionA: 'Live in a treehouse', optionB: 'Live in a houseboat', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q32', optionA: 'Have a pause button for your life', optionB: 'Have a fast-forward button', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q33', optionA: 'Be the funniest person in the room', optionB: 'Be the smartest person in the room', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q34', optionA: 'Always have exact change', optionB: 'Always have your phone fully charged', category: 'lifestyle'),
  WouldYouRatherQuestion(id: 'q35', optionA: 'Be a morning person', optionB: 'Be a night owl', category: 'lifestyle'),

  // Food & Drink (36-50)
  WouldYouRatherQuestion(id: 'q36', optionA: 'Eat only sweet foods', optionB: 'Eat only savory foods', category: 'food'),
  WouldYouRatherQuestion(id: 'q37', optionA: 'Never eat pizza again', optionB: 'Never eat ice cream again', category: 'food'),
  WouldYouRatherQuestion(id: 'q38', optionA: 'Drink only water for a year', optionB: 'Eat the same meal every day for a year', category: 'food'),
  WouldYouRatherQuestion(id: 'q39', optionA: 'Be a vegetarian', optionB: 'Only eat meat', category: 'food'),
  WouldYouRatherQuestion(id: 'q40', optionA: 'Never eat chocolate again', optionB: 'Never drink coffee again', category: 'food'),
  WouldYouRatherQuestion(id: 'q41', optionA: 'Have unlimited sushi for life', optionB: 'Have unlimited tacos for life', category: 'food'),
  WouldYouRatherQuestion(id: 'q42', optionA: 'Cook every meal yourself', optionB: 'Eat out every meal', category: 'food'),
  WouldYouRatherQuestion(id: 'q43', optionA: 'Only eat spicy food', optionB: 'Only eat bland food', category: 'food'),
  WouldYouRatherQuestion(id: 'q44', optionA: 'Give up breakfast', optionB: 'Give up dinner', category: 'food'),
  WouldYouRatherQuestion(id: 'q45', optionA: 'Have unlimited biryani', optionB: 'Have unlimited momos', category: 'food'),
  WouldYouRatherQuestion(id: 'q46', optionA: 'Never eat street food again', optionB: 'Never eat home-cooked food again', category: 'food'),
  WouldYouRatherQuestion(id: 'q47', optionA: 'Only drink chai', optionB: 'Only drink coffee', category: 'food'),
  WouldYouRatherQuestion(id: 'q48', optionA: 'Have maggi for every meal', optionB: 'Never eat maggi again', category: 'food'),
  WouldYouRatherQuestion(id: 'q49', optionA: 'Eat dessert before every meal', optionB: 'Never eat dessert again', category: 'food'),
  WouldYouRatherQuestion(id: 'q50', optionA: 'Only eat cold food', optionB: 'Only eat room temperature food', category: 'food'),

  // Technology & Social Media (51-65)
  WouldYouRatherQuestion(id: 'q51', optionA: 'Never use social media again', optionB: 'Never watch another movie or TV show', category: 'technology'),
  WouldYouRatherQuestion(id: 'q52', optionA: 'Give up your smartphone', optionB: 'Give up your laptop', category: 'technology'),
  WouldYouRatherQuestion(id: 'q53', optionA: 'Only use Instagram', optionB: 'Only use YouTube', category: 'technology'),
  WouldYouRatherQuestion(id: 'q54', optionA: 'Have every call be a video call', optionB: 'Never video call again', category: 'technology'),
  WouldYouRatherQuestion(id: 'q55', optionA: 'Have your browser history made public', optionB: 'Have your text messages made public', category: 'technology'),
  WouldYouRatherQuestion(id: 'q56', optionA: 'Only be able to use dark mode', optionB: 'Only be able to use light mode', category: 'technology'),
  WouldYouRatherQuestion(id: 'q57', optionA: 'Have 1 million followers but no real friends', optionB: 'Have 100 close friends but no online presence', category: 'technology'),
  WouldYouRatherQuestion(id: 'q58', optionA: 'Never use Google again', optionB: 'Never use YouTube again', category: 'technology'),
  WouldYouRatherQuestion(id: 'q59', optionA: 'Have your phone always at 10% battery', optionB: 'Have your phone always on loud', category: 'technology'),
  WouldYouRatherQuestion(id: 'q60', optionA: 'Only text to communicate', optionB: 'Only call to communicate', category: 'technology'),
  WouldYouRatherQuestion(id: 'q61', optionA: 'Have slow internet forever', optionB: 'Have no internet for one day a week', category: 'technology'),
  WouldYouRatherQuestion(id: 'q62', optionA: 'Live without Netflix', optionB: 'Live without Spotify', category: 'technology'),
  WouldYouRatherQuestion(id: 'q63', optionA: 'Have unlimited storage', optionB: 'Have unlimited data', category: 'technology'),
  WouldYouRatherQuestion(id: 'q64', optionA: 'Give up gaming forever', optionB: 'Give up streaming forever', category: 'technology'),
  WouldYouRatherQuestion(id: 'q65', optionA: 'Only use keyboard (no mouse)', optionB: 'Only use mouse (no keyboard)', category: 'technology'),

  // Travel & Adventure (66-80)
  WouldYouRatherQuestion(id: 'q66', optionA: 'Go on a beach vacation', optionB: 'Go on a mountain retreat', category: 'travel'),
  WouldYouRatherQuestion(id: 'q67', optionA: 'Travel to the past', optionB: 'Travel to the future', category: 'travel'),
  WouldYouRatherQuestion(id: 'q68', optionA: 'Go on a road trip', optionB: 'Go on a cruise', category: 'travel'),
  WouldYouRatherQuestion(id: 'q69', optionA: 'Visit every country but never return home', optionB: 'Never leave your country but have everything you need', category: 'travel'),
  WouldYouRatherQuestion(id: 'q70', optionA: 'Live in a different country every year', optionB: 'Stay in one place forever', category: 'travel'),
  WouldYouRatherQuestion(id: 'q71', optionA: 'Explore space', optionB: 'Explore the deep ocean', category: 'travel'),
  WouldYouRatherQuestion(id: 'q72', optionA: 'Travel first class', optionB: 'Have more trips in economy', category: 'travel'),
  WouldYouRatherQuestion(id: 'q73', optionA: 'Go bungee jumping', optionB: 'Go skydiving', category: 'travel'),
  WouldYouRatherQuestion(id: 'q74', optionA: 'Visit Ladakh', optionB: 'Visit Goa', category: 'travel'),
  WouldYouRatherQuestion(id: 'q75', optionA: 'Travel solo', optionB: 'Travel with a group', category: 'travel'),
  WouldYouRatherQuestion(id: 'q76', optionA: 'Stay in luxury hotels', optionB: 'Stay in unique Airbnbs', category: 'travel'),
  WouldYouRatherQuestion(id: 'q77', optionA: 'Take a train journey across India', optionB: 'Take a road trip across India', category: 'travel'),
  WouldYouRatherQuestion(id: 'q78', optionA: 'Visit ancient ruins', optionB: 'Visit modern cities', category: 'travel'),
  WouldYouRatherQuestion(id: 'q79', optionA: 'Go camping in the wilderness', optionB: 'Stay in a cozy cabin', category: 'travel'),
  WouldYouRatherQuestion(id: 'q80', optionA: 'Travel during festivals', optionB: 'Travel during off-season', category: 'travel'),

  // Relationships & Social (81-100)
  WouldYouRatherQuestion(id: 'q81', optionA: 'Have many acquaintances', optionB: 'Have few close friends', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q82', optionA: 'Know what others think of you', optionB: 'Never know what others think of you', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q83', optionA: 'Be in a long-distance relationship', optionB: 'Never be in a relationship', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q84', optionA: 'Have a partner who is very funny', optionB: 'Have a partner who is very romantic', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q85', optionA: 'Be the oldest sibling', optionB: 'Be the youngest sibling', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q86', optionA: 'Have a big wedding', optionB: 'Have a small intimate wedding', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q87', optionA: 'Meet your future self', optionB: 'Meet your past self', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q88', optionA: 'Have dinner with your favorite celebrity', optionB: 'Have dinner with a historical figure', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q89', optionA: 'Be the life of the party', optionB: 'Be the quiet observer', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q90', optionA: 'Have a friend who is always honest', optionB: 'Have a friend who is always supportive', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q91', optionA: 'Live with your best friend', optionB: 'Live with your partner', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q92', optionA: 'Have a surprise party thrown for you', optionB: 'Plan your own birthday party', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q93', optionA: 'Be known for your looks', optionB: 'Be known for your intelligence', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q94', optionA: 'Have a partner who loves the same things', optionB: 'Have a partner who introduces you to new things', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q95', optionA: 'Always win arguments', optionB: 'Never have arguments', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q96', optionA: 'Have your parents choose your career', optionB: 'Have your parents choose your partner', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q97', optionA: 'Be extremely attractive but unlucky in love', optionB: 'Be average looking but very lucky in love', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q98', optionA: 'Have a partner who cooks well', optionB: 'Have a partner who cleans well', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q99', optionA: 'Spend more time with family', optionB: 'Spend more time with friends', category: 'relationships'),
  WouldYouRatherQuestion(id: 'q100', optionA: 'Be loved by everyone but never find true love', optionB: 'Be hated by everyone but have one true love', category: 'relationships'),
];

/// Returns a list of random question IDs for a game session
List<String> getRandomQuestionIds({int count = 8}) {
  final random = Random();
  final allIds = wouldYouRatherQuestions.map((q) => q.id).toList();
  allIds.shuffle(random);
  return allIds.take(count).toList();
}

/// Get a question by its ID
WouldYouRatherQuestion? getQuestionById(String id) {
  try {
    return wouldYouRatherQuestions.firstWhere((q) => q.id == id);
  } catch (_) {
    return null;
  }
}

/// Get multiple questions by their IDs
List<WouldYouRatherQuestion> getQuestionsByIds(List<String> ids) {
  return ids.map((id) => getQuestionById(id)).whereType<WouldYouRatherQuestion>().toList();
}
