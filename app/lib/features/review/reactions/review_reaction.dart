// Review rating reaction state: variant distributions, durations, and the
// active-event budget. Ported from the flashcards reference
// (reviewReaction.ts + ReviewReactionState.swift) so SceneLex shares the
// same weights, durations, and max-3-active behavior.
library;

enum ReviewReactionRating { again, hard, good, easy }

const reviewReactionMaximumActiveEvents = 3;

/// Reduced-motion: hold the animation at this progress and clear quickly.
const reducedMotionAnimationProgress = 0.55;
const reducedMotionCleanupDelay = Duration(milliseconds: 400);

enum ReviewReactionVariant {
  againRainCloud,
  againTornado,
  againWindFace,
  againSnowflake,
  againSnailCrawl,
  againTurtle,
  againWiltedFlower,
  againSpider,
  againRat,
  againWormWiggle,
  hardTiger,
  hardTRex,
  hardShark,
  hardOxCharge,
  hardRacehorseGallop,
  hardSnake,
  hardVolcanoEruption,
  hardScorpion,
  hardPawPrints,
  hardRooster,
  goodOtter,
  goodOwl,
  goodRabbit,
  goodSeal,
  goodServiceDog,
  goodPoodle,
  goodChimpanzee,
  goodWhale,
  goodPeacock,
  goodPig,
  easySunrise,
  easySunriseOverMountains,
  easyRoseBloom,
  easyPeace,
  easyPlant,
  easyRainbowStreak,
  easyPhoenixRise,
  easyUnicornFlyby,
  fallbackCrownBounce,
}

class ReviewReactionEvent {
  const ReviewReactionEvent({
    required this.id,
    required this.rating,
    required this.variant,
  });

  final String id;
  final ReviewReactionRating rating;
  final ReviewReactionVariant variant;
}

class ReviewReactionVariantDistributionEntry {
  const ReviewReactionVariantDistributionEntry({
    required this.rating,
    required this.variant,
    required this.weight,
  });

  final ReviewReactionRating rating;
  final ReviewReactionVariant variant;
  final int weight;
}

const List<ReviewReactionVariantDistributionEntry>
allReviewReactionVariantDistributionEntries = [
  // again (18)
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.again,
    variant: ReviewReactionVariant.againRainCloud,
    weight: 32,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.again,
    variant: ReviewReactionVariant.againTornado,
    weight: 26,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.again,
    variant: ReviewReactionVariant.againWindFace,
    weight: 24,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.again,
    variant: ReviewReactionVariant.againSnowflake,
    weight: 18,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.again,
    variant: ReviewReactionVariant.againSnailCrawl,
    weight: 18,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.again,
    variant: ReviewReactionVariant.againTurtle,
    weight: 16,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.again,
    variant: ReviewReactionVariant.againWiltedFlower,
    weight: 12,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.again,
    variant: ReviewReactionVariant.againSpider,
    weight: 8,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.again,
    variant: ReviewReactionVariant.againRat,
    weight: 8,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.again,
    variant: ReviewReactionVariant.againWormWiggle,
    weight: 6,
  ),
  // hard (10)
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.hard,
    variant: ReviewReactionVariant.hardTiger,
    weight: 32,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.hard,
    variant: ReviewReactionVariant.hardTRex,
    weight: 26,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.hard,
    variant: ReviewReactionVariant.hardShark,
    weight: 22,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.hard,
    variant: ReviewReactionVariant.hardOxCharge,
    weight: 20,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.hard,
    variant: ReviewReactionVariant.hardRacehorseGallop,
    weight: 18,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.hard,
    variant: ReviewReactionVariant.hardSnake,
    weight: 16,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.hard,
    variant: ReviewReactionVariant.hardVolcanoEruption,
    weight: 14,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.hard,
    variant: ReviewReactionVariant.hardScorpion,
    weight: 10,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.hard,
    variant: ReviewReactionVariant.hardPawPrints,
    weight: 8,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.hard,
    variant: ReviewReactionVariant.hardRooster,
    weight: 8,
  ),
  // good (10)
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.good,
    variant: ReviewReactionVariant.goodOtter,
    weight: 32,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.good,
    variant: ReviewReactionVariant.goodOwl,
    weight: 28,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.good,
    variant: ReviewReactionVariant.goodRabbit,
    weight: 26,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.good,
    variant: ReviewReactionVariant.goodSeal,
    weight: 24,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.good,
    variant: ReviewReactionVariant.goodServiceDog,
    weight: 24,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.good,
    variant: ReviewReactionVariant.goodPoodle,
    weight: 20,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.good,
    variant: ReviewReactionVariant.goodChimpanzee,
    weight: 18,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.good,
    variant: ReviewReactionVariant.goodWhale,
    weight: 16,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.good,
    variant: ReviewReactionVariant.goodPeacock,
    weight: 12,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.good,
    variant: ReviewReactionVariant.goodPig,
    weight: 10,
  ),
  // easy (8)
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.easy,
    variant: ReviewReactionVariant.easySunrise,
    weight: 34,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.easy,
    variant: ReviewReactionVariant.easySunriseOverMountains,
    weight: 34,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.easy,
    variant: ReviewReactionVariant.easyRoseBloom,
    weight: 30,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.easy,
    variant: ReviewReactionVariant.easyPeace,
    weight: 28,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.easy,
    variant: ReviewReactionVariant.easyPlant,
    weight: 26,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.easy,
    variant: ReviewReactionVariant.easyRainbowStreak,
    weight: 24,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.easy,
    variant: ReviewReactionVariant.easyPhoenixRise,
    weight: 18,
  ),
  ReviewReactionVariantDistributionEntry(
    rating: ReviewReactionRating.easy,
    variant: ReviewReactionVariant.easyUnicornFlyby,
    weight: 12,
  ),
];

List<ReviewReactionVariantDistributionEntry>
reviewReactionVariantDistributionEntries(ReviewReactionRating rating) =>
    allReviewReactionVariantDistributionEntries
        .where((entry) => entry.rating == rating)
        .toList();

int reviewReactionVariantTotalWeight(ReviewReactionRating rating) {
  var totalWeight = 0;
  for (final entry in reviewReactionVariantDistributionEntries(rating)) {
    totalWeight += entry.weight;
  }
  return totalWeight;
}

ReviewReactionVariant selectReviewReactionVariant(
  ReviewReactionRating rating,
  int roll,
) {
  final entries = reviewReactionVariantDistributionEntries(rating);
  var cumulativeWeight = 0;
  for (final entry in entries) {
    cumulativeWeight += entry.weight;
    if (roll < cumulativeWeight) {
      return entry.variant;
    }
  }
  return entries.last.variant;
}

ReviewReactionRating makeReviewReactionRating(int rating) => switch (rating) {
  0 => ReviewReactionRating.again,
  1 => ReviewReactionRating.hard,
  2 => ReviewReactionRating.good,
  _ => ReviewReactionRating.easy,
};

/// Keeps at most [maximumActiveEvents] events on screen (oldest dropped).
List<ReviewReactionEvent> appendReviewReactionEvent(
  List<ReviewReactionEvent> events,
  ReviewReactionEvent event,
  int maximumActiveEvents,
) {
  final nextEvents = [...events, event];
  if (nextEvents.length <= maximumActiveEvents) {
    return nextEvents;
  }
  return nextEvents.sublist(nextEvents.length - maximumActiveEvents);
}

/// Reference animation duration for the variant (milliseconds).
int reviewReactionAnimationDurationMillis(ReviewReactionVariant variant) =>
    switch (variant) {
      ReviewReactionVariant.againWindFace => 1600,
      ReviewReactionVariant.hardTRex => 1550,
      ReviewReactionVariant.hardRacehorseGallop => 1200,
      ReviewReactionVariant.easySunriseOverMountains => 1200,
      ReviewReactionVariant.goodRabbit => 1333,
      ReviewReactionVariant.easyRoseBloom => 2400,
      ReviewReactionVariant.againSpider => 2400,
      ReviewReactionVariant.goodPeacock => 1333,
      ReviewReactionVariant.againTornado => 1450,
      ReviewReactionVariant.hardOxCharge => 1550,
      ReviewReactionVariant.hardScorpion => 1800,
      ReviewReactionVariant.hardPawPrints ||
      ReviewReactionVariant.fallbackCrownBounce => 1650,
      ReviewReactionVariant.easyRainbowStreak => 2000,
      ReviewReactionVariant.hardVolcanoEruption => 2050,
      ReviewReactionVariant.againWiltedFlower => 2400,
      ReviewReactionVariant.goodSeal => 2567,
      ReviewReactionVariant.goodWhale => 2633,
      ReviewReactionVariant.againRat => 2633,
      ReviewReactionVariant.againSnailCrawl => 2700,
      ReviewReactionVariant.hardRooster => 2850,
      ReviewReactionVariant.easyPhoenixRise => 3933,
      ReviewReactionVariant.goodPoodle => 2800,
      ReviewReactionVariant.goodOwl => 2833,
      ReviewReactionVariant.goodOtter ||
      ReviewReactionVariant.goodServiceDog => 3000,
      ReviewReactionVariant.easyPeace => 3167,
      ReviewReactionVariant.hardShark => 3200,
      ReviewReactionVariant.againRainCloud ||
      ReviewReactionVariant.hardSnake => 3267,
      ReviewReactionVariant.againTurtle => 3400,
      ReviewReactionVariant.goodPig => 3567,
      ReviewReactionVariant.goodChimpanzee => 3833,
      ReviewReactionVariant.easyUnicornFlyby => 3800,
      ReviewReactionVariant.againSnowflake ||
      ReviewReactionVariant.hardTiger ||
      ReviewReactionVariant.easySunrise ||
      ReviewReactionVariant.easyPlant => 4200,
      ReviewReactionVariant.againWormWiggle => 4267,
    };

Duration reviewReactionCleanupDelay(
  ReviewReactionVariant variant, {
  required bool reducedMotion,
}) {
  if (reducedMotion) return reducedMotionCleanupDelay;
  return Duration(
    milliseconds: reviewReactionAnimationDurationMillis(variant) + 80,
  );
}

/// Opacity curve: fade in over the first 10%, fade out over the last 22%.
double reviewReactionOpacity(double progress) {
  final fadeIn = (progress / 0.10).clamp(0.0, 1.0);
  final fadeOut = ((1 - progress) / 0.22).clamp(0.0, 1.0);
  return (fadeIn < fadeOut ? fadeIn : fadeOut).clamp(0.0, 1.0);
}

/// Display scale of the Lottie canvas per variant (reference frame scales).
double reviewReactionFrameScale(ReviewReactionVariant variant) =>
    switch (variant) {
      ReviewReactionVariant.againRainCloud => 0.62,
      ReviewReactionVariant.againTornado => 0.58,
      ReviewReactionVariant.againWindFace => 0.56,
      ReviewReactionVariant.againSnowflake => 0.56,
      ReviewReactionVariant.againSnailCrawl => 0.58,
      ReviewReactionVariant.againTurtle => 0.58,
      ReviewReactionVariant.againWiltedFlower => 0.56,
      ReviewReactionVariant.againSpider => 0.54,
      ReviewReactionVariant.againRat => 0.56,
      ReviewReactionVariant.againWormWiggle => 0.58,
      ReviewReactionVariant.hardTiger => 0.62,
      ReviewReactionVariant.hardTRex => 0.62,
      ReviewReactionVariant.hardShark => 0.62,
      ReviewReactionVariant.hardOxCharge => 0.58,
      ReviewReactionVariant.hardRacehorseGallop => 0.62,
      ReviewReactionVariant.hardSnake => 0.58,
      ReviewReactionVariant.hardVolcanoEruption => 0.64,
      ReviewReactionVariant.hardScorpion => 0.56,
      ReviewReactionVariant.hardPawPrints => 0.56,
      ReviewReactionVariant.hardRooster => 0.58,
      ReviewReactionVariant.goodOtter => 0.58,
      ReviewReactionVariant.goodOwl => 0.56,
      ReviewReactionVariant.goodRabbit => 0.56,
      ReviewReactionVariant.goodSeal => 0.58,
      ReviewReactionVariant.goodServiceDog => 0.58,
      ReviewReactionVariant.goodPoodle => 0.56,
      ReviewReactionVariant.goodChimpanzee => 0.56,
      ReviewReactionVariant.goodWhale => 0.58,
      ReviewReactionVariant.goodPeacock => 0.58,
      ReviewReactionVariant.goodPig => 0.56,
      ReviewReactionVariant.easySunrise => 0.64,
      ReviewReactionVariant.easySunriseOverMountains => 0.64,
      ReviewReactionVariant.easyRoseBloom => 0.58,
      ReviewReactionVariant.easyPeace => 0.56,
      ReviewReactionVariant.easyPlant => 0.58,
      ReviewReactionVariant.easyRainbowStreak => 0.64,
      ReviewReactionVariant.easyPhoenixRise => 0.64,
      ReviewReactionVariant.easyUnicornFlyby => 0.52,
      ReviewReactionVariant.fallbackCrownBounce => 0.56,
    };

/// Asset path for a Lottie variant (null for the canvas crown fallback).
String? reviewReactionLottieAssetPath(
  ReviewReactionVariant variant,
) => switch (variant) {
  ReviewReactionVariant.againRainCloud =>
    'assets/reactions/review_again_rain_cloud.json',
  ReviewReactionVariant.againTornado =>
    'assets/reactions/review_again_tornado.json',
  ReviewReactionVariant.againWindFace =>
    'assets/reactions/review_again_wind_face.json',
  ReviewReactionVariant.againSnowflake =>
    'assets/reactions/review_again_snowflake.json',
  ReviewReactionVariant.againSnailCrawl =>
    'assets/reactions/review_again_snail.json',
  ReviewReactionVariant.againTurtle =>
    'assets/reactions/review_again_turtle.json',
  ReviewReactionVariant.againWiltedFlower =>
    'assets/reactions/review_again_wilted_flower.json',
  ReviewReactionVariant.againSpider =>
    'assets/reactions/review_again_spider.json',
  ReviewReactionVariant.againRat => 'assets/reactions/review_again_rat.json',
  ReviewReactionVariant.againWormWiggle =>
    'assets/reactions/review_again_worm.json',
  ReviewReactionVariant.hardTiger => 'assets/reactions/review_hard_tiger.json',
  ReviewReactionVariant.hardTRex => 'assets/reactions/review_hard_t_rex.json',
  ReviewReactionVariant.hardShark => 'assets/reactions/review_hard_shark.json',
  ReviewReactionVariant.hardOxCharge => 'assets/reactions/review_hard_ox.json',
  ReviewReactionVariant.hardRacehorseGallop =>
    'assets/reactions/review_hard_racehorse.json',
  ReviewReactionVariant.hardSnake => 'assets/reactions/review_hard_snake.json',
  ReviewReactionVariant.hardVolcanoEruption =>
    'assets/reactions/review_hard_volcano.json',
  ReviewReactionVariant.hardScorpion =>
    'assets/reactions/review_hard_scorpion.json',
  ReviewReactionVariant.hardPawPrints =>
    'assets/reactions/review_hard_paw_prints.json',
  ReviewReactionVariant.hardRooster =>
    'assets/reactions/review_hard_rooster.json',
  ReviewReactionVariant.goodOtter => 'assets/reactions/review_good_otter.json',
  ReviewReactionVariant.goodOwl => 'assets/reactions/review_good_owl.json',
  ReviewReactionVariant.goodRabbit =>
    'assets/reactions/review_good_rabbit.json',
  ReviewReactionVariant.goodSeal => 'assets/reactions/review_good_seal.json',
  ReviewReactionVariant.goodServiceDog =>
    'assets/reactions/review_good_service_dog.json',
  ReviewReactionVariant.goodPoodle =>
    'assets/reactions/review_good_poodle.json',
  ReviewReactionVariant.goodChimpanzee =>
    'assets/reactions/review_good_chimpanzee.json',
  ReviewReactionVariant.goodWhale => 'assets/reactions/review_good_whale.json',
  ReviewReactionVariant.goodPeacock =>
    'assets/reactions/review_good_peacock.json',
  ReviewReactionVariant.goodPig => 'assets/reactions/review_good_pig.json',
  ReviewReactionVariant.easySunrise =>
    'assets/reactions/review_easy_sunrise.json',
  ReviewReactionVariant.easySunriseOverMountains =>
    'assets/reactions/review_easy_sunrise_over_mountains.json',
  ReviewReactionVariant.easyRoseBloom =>
    'assets/reactions/review_easy_rose.json',
  ReviewReactionVariant.easyPeace => 'assets/reactions/review_easy_peace.json',
  ReviewReactionVariant.easyPlant => 'assets/reactions/review_easy_plant.json',
  ReviewReactionVariant.easyRainbowStreak =>
    'assets/reactions/review_easy_rainbow.json',
  ReviewReactionVariant.easyPhoenixRise =>
    'assets/reactions/review_easy_phoenix.json',
  ReviewReactionVariant.easyUnicornFlyby =>
    'assets/reactions/review_easy_unicorn.json',
  ReviewReactionVariant.fallbackCrownBounce => null,
};
