-- Progress lane must work before the content lane exists (offline-first:
-- a client can create learning states for senses it has not downloaded yet).
ALTER TABLE content.learning_states
    DROP CONSTRAINT learning_states_word_sense_id_fkey;
