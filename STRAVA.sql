USE strava;
SHOW TABLES;
SELECT * FROM dailyactivity_merged;
#  Checking Number of Rows on dailyactivity_merged
SELECT COUNT(*) FROM dailyactivity_merged;

-- Checking for duplicates in dailyactivity_merged
SELECT Id, ActivityDate, TotalSteps, Count(*)
FROM dailyactivity_merged
GROUP BY id, ActivityDate, TotalSteps
HAVING Count(*) > 1;

describe dailyactivity_merged;

# Modify date format for better understaning in dailyactivity_merged
SELECT ActivityDate,
       STR_TO_DATE(ActivityDate, '%m/%d/%Y') AS converted_date
FROM dailyactivity_merged
limit 20;
SET SQL_SAFE_UPDATES = 0;
SET SQL_SAFE_UPDATES = 1;

# Extract datename from ActivityDate
SET SQL_SAFE_UPDATES = 0;
Update dailyactivity_merged
SET day_of_week = DAYNAME(ActivityDate);
SET SQL_SAFE_UPDATES = 1;

 # Add sleep data columns on dailyactivity_merged
SET SQL_SAFE_UPDATES = 0; 
Alter Table dailyactivity_merged
ADD column total_minutes_sleep int,
ADD column total_time_in_bed int;

# Add sleep records into dailyactivity_merged
UPDATE dailyactivity_merged AS da
JOIN sleepday_merged AS sd
  ON da.Id = sd.Id AND da.ActivityDate = sd.SleepDay
SET 
  da.total_minutes_sleep = sd.TotalMinutesAsleep,
  da.total_time_in_bed = sd.TotalTimeInBed;
  
 # Split date and time for hourlycalories_merged
ALTER TABLE hourlycalories_merged
ADD COLUMN time_new INT,
ADD COLUMN date_new DATE;
UPDATE hourlycalories_merged
SET time_new = HOUR(STR_TO_DATE(ActivityHour, '%m/%d/%Y %r'));
UPDATE hourlycalories_merged
SET date_new = DATE(STR_TO_DATE(ActivityHour, '%m/%d/%Y %r'));

# Split date and time seperately for hourlyintensities_merged
ALTER TABLE hourlyintensities_merged
ADD COLUMN time_new INT,
ADD COLUMN date_new DATE;
UPDATE hourlyintensities_merged
SET time_new = HOUR(STR_TO_DATE(ActivityHour, '%m/%d/%Y %r'));
UPDATE hourlyintensities_merged
SET date_new = DATE(STR_TO_DATE(ActivityHour, '%m/%d/%Y %r'));

# Split date and time seperately for hourlysteps_merged
ALTER TABLE hourlysteps_merged
ADD COLUMN time_new INT,
ADD COLUMN date_new DATE;
UPDATE hourlysteps_merged
SET time_new = HOUR(STR_TO_DATE(ActivityHour, '%m/%d/%Y %r'));
UPDATE hourlysteps_merged
SET date_new = DATE(STR_TO_DATE(ActivityHour, '%m/%d/%Y %r'));

# Split date and time seperately for minutemetsnarrow_merged
ALTER TABLE minutemetsnarrow_merged
ADD COLUMN time_new TIME,
ADD COLUMN date_new DATE;
SET SQL_SAFE_UPDATES = 0;
UPDATE minutemetsnarrow_merged
SET time_new = TIME(STR_TO_DATE(ActivityMinute, '%m/%d/%Y %r'));
SET SQL_SAFE_UPDATES = 0;
UPDATE minutemetsnarrow_merged
SET date_new = DATE(STR_TO_DATE(ActivityMinute, '%m/%d/%Y %r'));

# Create new table to merge hourlycalories_merged, hourlyintensities_merged, and hourlysteps_merged
CREATE TABLE hourly_data_merge (
  id BIGINT,
  date_new VARCHAR(50),
  time_new INT,
  calories BIGINT,
  total_intensity BIGINT,
  average_intensity FLOAT,
  step_total BIGINT
);

INSERT INTO hourly_data_merge (
  id, date_new, time_new, calories, total_intensity, average_intensity, step_total
)
SELECT 
  temp1.id,
  temp1.date_new,
  temp1.time_new,
  temp1.Calories,
  temp2.TotalIntensity,
  temp2.AverageIntensity,
  temp3.StepTotal
FROM hourlycalories_merged AS temp1
INNER JOIN hourlyintensities_merged AS temp2
  ON temp1.id = temp2.id
     AND temp1.date_new = temp2.date_new
     AND temp1.time_new = temp2.time_new
INNER JOIN hourlysteps_merged AS temp3
  ON temp1.id = temp3.id
     AND temp1.date_new = temp3.date_new
     AND temp1.time_new = temp3.time_new;
     
# Checking for duplicates
SELECT id, time_new, calories, total_intensity, average_intensity, step_total, Count(*) as duplicates
      FROM hourly_data_merge
      GROUP BY id, time_new, calories, total_intensity, average_intensity, step_total
      HAVING Count(*) > 1;
SELECT sum(duplicates) as total_duplicates
FROM (SELECT id, time_new, calories, total_intensity, average_intensity, step_total, Count(*) as duplicates
      FROM hourly_data_merge
      GROUP BY id, time_new, calories, total_intensity, average_intensity, step_total
      HAVING Count(*) > 1) AS temp;
      

# Daily Average analysis
Select AVG(TotalSteps) as avg_steps,
AVG(TotalDistance) as avg_distance,
AVG(Calories) as avg_calories,
day_of_week
From dailyactivity_merged
Group By  day_of_week;

# Daily Sum Analysis - No trends/patterns found
Select SUM(TotalSteps) as total_steps,
SUM(TotalDistance) as total_distance,
SUM(Calories) as total_calories,
day_of_week
From dailyactivity_merged
Group By  day_of_week;

# Activities and colories comparison
Select Id,
SUM(TotalSteps) as total_steps,
SUM(VeryActiveMinutes) as total_very_active_mins,
Sum(FairlyActiveMinutes) as total_fairly_active_mins,
SUM(LightlyActiveMinutes) as total_lightly_active_mins,
SUM(Calories) as total_calories
From dailyactivity_merged
Group By Id


SELECT * FROM sleepday_merged LIMIT 5;

# Average Sleep Time per user
SELECT 
  Id, 
  AVG(TotalMinutesAsleep) / 60 AS avg_sleep_time_hour,
  AVG(TotalTimeInBed) / 60 AS avg_time_bed_hour,
  AVG(TotalTimeInBed - TotalMinutesAsleep) AS wasted_bed_time_min
FROM sleepday_merged
GROUP BY Id;

# Sleep and calories comparison 
SELECT 
  da.Id, 
  SUM(sd.TotalMinutesAsleep) AS total_sleep_min,
  SUM(sd.TotalTimeInBed) AS total_time_inbed_min,
  SUM(da.Calories) AS total_calories
FROM dailyactivity_merged AS da
JOIN sleepday_merged AS sd
  ON da.Id = sd.Id
     AND da.ActivityDate = DATE(STR_TO_DATE(sd.SleepDay, '%c/%e/%Y %r'))
GROUP BY da.Id;

# average met per day per user, and compare with the calories burned
SELECT 
  temp1.Id, 
  temp1.date_new, 
  SUM(temp1.METs) AS sum_mets, 
  temp2.Calories
FROM minutemetsnarrow_merged AS temp1
INNER JOIN dailyactivity_merged AS temp2
  ON temp1.Id = temp2.Id 
     AND temp1.date_new = temp2.ActivityDate
GROUP BY temp1.Id, temp1.date_new, temp2.Calories
ORDER BY temp1.date_new
LIMIT 20;

# Time spent on activity per day
Select Distinct Id, SUM(SedentaryMinutes) as sedentary_mins,
SUM(LightlyActiveMinutes) as lightly_active_mins,
SUM(FairlyActiveMinutes) as fairly_active_mins, 
SUM(VeryActiveMinutes) as very_active_mins
From dailyactivity_merged
where total_time_in_bed IS NULL
Group by Id


