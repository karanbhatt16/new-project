const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * Trigger: onCreate of /games/two_truths_one_lie/guesses/{guessId}
 * - Reads target's private lie index
 * - Sets guess.isCorrect accordingly
 * - Increments leaderboard counters for guesser (correctGuesses, totalGuesses)
 * - Increments leaderboard counters for target (peopleFooled, timesGuessedOn)
 */
exports.onTwoTruthsGuessCreated = functions.firestore
  .document('games/two_truths_one_lie/guesses/{guessId}')
  .onCreate(async (snapshot, context) => {
    const db = admin.firestore();
    const guess = snapshot.data();
    if (!guess) return null;

    const { guesserUid, targetUid, guessedLieIndex } = guess;
    if (!guesserUid || !targetUid || typeof guessedLieIndex !== 'number') {
      console.warn('Invalid guess payload', guess);
      return null;
    }

    try {
      const privateRef = db.collection('games').doc('two_truths_one_lie').collection('private_submissions').doc(targetUid);
      const privateSnap = await privateRef.get();
      if (!privateSnap.exists) {
        console.log('No private submission for target', targetUid);
        await snapshot.ref.update({ isCorrect: false });
        return null;
      }

      const lieIndex = privateSnap.data().lieIndex;
      const isCorrect = lieIndex === guessedLieIndex;

      // Update guess doc with correctness (may already be set by client, but ensure server truth)
      await snapshot.ref.update({ isCorrect });

      // Update leaderboard counters for guesser
      const guesserLbRef = db.collection('games').doc('two_truths_one_lie').collection('leaderboard').doc(guesserUid);
      await db.runTransaction(async (tx) => {
        const lbSnap = await tx.get(guesserLbRef);
        const prev = lbSnap.exists ? lbSnap.data() : { 
          correctGuesses: 0, 
          totalGuesses: 0,
          peopleFooled: 0,
          timesGuessedOn: 0,
        };
        const next = {
          correctGuesses: (prev.correctGuesses || 0) + (isCorrect ? 1 : 0),
          totalGuesses: (prev.totalGuesses || 0) + 1,
          peopleFooled: prev.peopleFooled || 0,
          timesGuessedOn: prev.timesGuessedOn || 0,
          updatedAt: new Date().toISOString(),
        };
        tx.set(guesserLbRef, next, { merge: true });
      });

      // Update leaderboard counters for target (the person whose statements were guessed)
      const targetLbRef = db.collection('games').doc('two_truths_one_lie').collection('leaderboard').doc(targetUid);
      await db.runTransaction(async (tx) => {
        const lbSnap = await tx.get(targetLbRef);
        const prev = lbSnap.exists ? lbSnap.data() : { 
          correctGuesses: 0, 
          totalGuesses: 0,
          peopleFooled: 0,
          timesGuessedOn: 0,
        };
        const next = {
          correctGuesses: prev.correctGuesses || 0,
          totalGuesses: prev.totalGuesses || 0,
          peopleFooled: (prev.peopleFooled || 0) + (isCorrect ? 0 : 1), // Fooled if guesser was wrong
          timesGuessedOn: (prev.timesGuessedOn || 0) + 1,
          updatedAt: new Date().toISOString(),
        };
        tx.set(targetLbRef, next, { merge: true });
      });

      console.log(`Guess processed: guesser=${guesserUid}, target=${targetUid}, correct=${isCorrect}`);
    } catch (e) {
      console.error('Error processing guess', e);
    }

    return null;
  });
