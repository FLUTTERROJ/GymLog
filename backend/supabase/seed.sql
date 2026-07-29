-- ============================================================================
-- Global exercise catalogue.
-- Safe to re-run: the partial unique index on global names makes this a no-op
-- for anything already present.
-- ============================================================================

insert into public.exercises (name, muscle_group, is_global, created_by) values
  -- Chest
  ('Barbell Bench Press',        'Chest',      true, null),
  ('Incline Barbell Bench Press','Chest',      true, null),
  ('Dumbbell Bench Press',       'Chest',      true, null),
  ('Incline Dumbbell Press',     'Chest',      true, null),
  ('Dumbbell Fly',               'Chest',      true, null),
  ('Cable Crossover',            'Chest',      true, null),
  ('Chest Press Machine',        'Chest',      true, null),
  ('Push Up',                    'Chest',      true, null),
  ('Dips',                       'Chest',      true, null),

  -- Back
  ('Deadlift',                   'Back',       true, null),
  ('Romanian Deadlift',          'Back',       true, null),
  ('Pull Up',                    'Back',       true, null),
  ('Chin Up',                    'Back',       true, null),
  ('Lat Pulldown',               'Back',       true, null),
  ('Barbell Row',                'Back',       true, null),
  ('Dumbbell Row',               'Back',       true, null),
  ('Seated Cable Row',           'Back',       true, null),
  ('T-Bar Row',                  'Back',       true, null),
  ('Face Pull',                  'Back',       true, null),
  ('Straight Arm Pulldown',      'Back',       true, null),
  ('Shrug',                      'Back',       true, null),
  ('Hyperextension',             'Back',       true, null),

  -- Legs
  ('Back Squat',                 'Legs',       true, null),
  ('Front Squat',                'Legs',       true, null),
  ('Hack Squat',                 'Legs',       true, null),
  ('Leg Press',                  'Legs',       true, null),
  ('Bulgarian Split Squat',      'Legs',       true, null),
  ('Walking Lunge',              'Legs',       true, null),
  ('Goblet Squat',               'Legs',       true, null),
  ('Leg Extension',              'Legs',       true, null),
  ('Lying Leg Curl',             'Legs',       true, null),
  ('Seated Leg Curl',            'Legs',       true, null),
  ('Hip Thrust',                 'Legs',       true, null),
  ('Standing Calf Raise',        'Legs',       true, null),
  ('Seated Calf Raise',          'Legs',       true, null),
  ('Hip Abduction Machine',      'Legs',       true, null),

  -- Shoulders
  ('Overhead Press',             'Shoulders',  true, null),
  ('Seated Dumbbell Press',      'Shoulders',  true, null),
  ('Arnold Press',               'Shoulders',  true, null),
  ('Lateral Raise',              'Shoulders',  true, null),
  ('Cable Lateral Raise',        'Shoulders',  true, null),
  ('Front Raise',                'Shoulders',  true, null),
  ('Rear Delt Fly',              'Shoulders',  true, null),
  ('Upright Row',                'Shoulders',  true, null),

  -- Arms
  ('Barbell Curl',               'Arms',       true, null),
  ('Dumbbell Curl',              'Arms',       true, null),
  ('Hammer Curl',                'Arms',       true, null),
  ('Preacher Curl',              'Arms',       true, null),
  ('Incline Dumbbell Curl',      'Arms',       true, null),
  ('Cable Curl',                 'Arms',       true, null),
  ('Concentration Curl',         'Arms',       true, null),
  ('Tricep Pushdown',            'Arms',       true, null),
  ('Rope Pushdown',              'Arms',       true, null),
  ('Overhead Tricep Extension',  'Arms',       true, null),
  ('Skull Crusher',              'Arms',       true, null),
  ('Close Grip Bench Press',     'Arms',       true, null),
  ('Tricep Kickback',            'Arms',       true, null),
  ('Wrist Curl',                 'Arms',       true, null),

  -- Core
  ('Plank',                      'Core',       true, null),
  ('Hanging Leg Raise',          'Core',       true, null),
  ('Cable Crunch',               'Core',       true, null),
  ('Crunch',                     'Core',       true, null),
  ('Russian Twist',              'Core',       true, null),
  ('Ab Wheel Rollout',           'Core',       true, null),
  ('Mountain Climber',           'Core',       true, null),
  ('Sit Up',                     'Core',       true, null),

  -- Conditioning
  ('Treadmill Run',              'Cardio',     true, null),
  ('Stationary Bike',            'Cardio',     true, null),
  ('Rowing Machine',             'Cardio',     true, null),
  ('Elliptical',                 'Cardio',     true, null),
  ('Stair Climber',              'Cardio',     true, null),
  ('Jump Rope',                  'Cardio',     true, null),
  ('Battle Ropes',               'Cardio',     true, null),
  ('Farmer''s Walk',             'Full Body',  true, null),
  ('Kettlebell Swing',           'Full Body',  true, null),
  ('Burpee',                     'Full Body',  true, null),
  ('Clean and Press',            'Full Body',  true, null)
on conflict do nothing;
