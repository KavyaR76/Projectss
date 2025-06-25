-- Q15 Top 5 doctors who generated the most revenue but had the fewest patients
SELECT 
    d.Doctor_Name,
    COUNT(DISTINCT d.patient_id) AS patient_count,
    SUM(d.Total_Bill) AS total_revenue
FROM er_doctor d
GROUP BY d.Doctor_Name
ORDER BY total_revenue DESC, patient_count ASC
LIMIT 5;

-- Q16 Department where average waiting time has decreased over three consecutive months
WITH avg_waits AS (
  SELECT 
    department_referral,
    YEAR(visit_date) AS yr,
    MONTH(visit_date) AS mth,
    AVG(patient_waittime) AS avg_wait
  FROM er_patients
  GROUP BY department_referral, yr, mth
),
ordered_waits AS (
  SELECT *,
         LAG(avg_wait, 1) OVER (PARTITION BY department_referral ORDER BY yr, mth) AS prev1,
         LAG(avg_wait, 2) OVER (PARTITION BY department_referral ORDER BY yr, mth) AS prev2
  FROM avg_waits
)
SELECT DISTINCT department_referral
FROM ordered_waits
WHERE prev2 IS NOT NULL
  AND avg_wait < prev1
  AND prev1 < prev2;

-- Q17 Ratio of male to female patients per doctor, ranked by ratio
SELECT 
    d.Doctor_Name,
    SUM(CASE WHEN p.patient_gender = 'Male' THEN 1 ELSE 0 END) AS male_count,
    SUM(CASE WHEN p.patient_gender = 'Female' THEN 1 ELSE 0 END) AS female_count,
    ROUND(
      1.0 * SUM(CASE WHEN p.patient_gender = 'Male' THEN 1 ELSE 0 END) /
      NULLIF(SUM(CASE WHEN p.patient_gender = 'Female' THEN 1 ELSE 0 END), 0), 2
    ) AS male_female_ratio
FROM er_doctor d
JOIN er_patients p ON d.patient_id = p.patient_id
GROUP BY d.Doctor_Name
ORDER BY male_female_ratio DESC;

-- Q18 Average satisfaction score of patients per doctor
SELECT 
    d.Doctor_Name,
    ROUND(AVG(p.patient_sat_score), 2) AS avg_satisfaction
FROM er_doctor d
JOIN er_patients p ON d.patient_id = p.patient_id
GROUP BY d.Doctor_Name
ORDER BY avg_satisfaction DESC;

-- Q19 Doctors who treated patients from different races (diversity count)
SELECT 
    d.Doctor_Name,
    COUNT(DISTINCT p.patient_race) AS race_diversity
FROM er_doctor d
JOIN er_patients p ON d.patient_id = p.patient_id
GROUP BY d.Doctor_Name
ORDER BY race_diversity DESC;

-- Q20 Ratio of total bills (male to female) per department
SELECT 
    d.department_referral,
    ROUND(
        SUM(CASE WHEN p.patient_gender = 'Male' THEN d.Total_Bill ELSE 0 END) /
        NULLIF(SUM(CASE WHEN p.patient_gender = 'Female' THEN d.Total_Bill ELSE 0 END), 0), 2
    ) AS male_female_bill_ratio
FROM er_doctor d
JOIN er_patients p ON d.patient_id = p.patient_id
GROUP BY d.department_referral;

-- Q21
-- UPDATE er_patients
-- SET patient_sat_score = LEAST(patient_sat_score + 2, 10)
-- WHERE department_referral = 'General Practice'
--   AND patient_waittime > 30;


-- Q1: Wait time vs satisfaction score
SELECT ROUND(AVG(patient_waittime), 2) AS avg_wait_time,
       ROUND(AVG(patient_sat_score), 2) AS avg_satisfaction
FROM er_patients;

-- Q2: Patient demographics and department visits
SELECT patient_gender, Age_Group, department_referral, COUNT(*) AS visit_count
FROM er_patients
GROUP BY patient_gender, Age_Group, department_referral
ORDER BY visit_count DESC
limit 20;

-- Q3: Monthly trends in patient visits
SELECT Year, Month, COUNT(*) AS monthly_visits
FROM er_patients
GROUP BY Year, Month
ORDER BY Year, FIELD(Month, 'January','February','March','April','May','June','July','August','September','October','November','December');

-- Q4: Age groups with satisfaction
SELECT Age_Group, ROUND(AVG(patient_sat_score), 2) AS avg_satisfaction, COUNT(*) AS num_patients
FROM er_patients
GROUP BY Age_Group
ORDER BY avg_satisfaction DESC;

-- Q5: Check for racial/gender discrimination
SELECT department_referral, patient_gender,
       ROUND(AVG(patient_sat_score), 2) AS avg_satisfaction,
       COUNT(*) AS num_patients
FROM er_patients
GROUP BY department_referral, patient_gender
ORDER BY department_referral, patient_gender;

SELECT department_referral, patient_race,
       ROUND(AVG(patient_sat_score), 2) AS avg_satisfaction,
       COUNT(*) AS num_patients
FROM er_patients
GROUP BY department_referral, patient_race
ORDER BY department_referral, patient_race;

-- Q6: Discount assignment logic
WITH categorized_scores AS (
    SELECT 
        patient_id,
        Age_Group,
        patient_sat_score,
        CASE
            WHEN patient_sat_score > 7 THEN 'HIGH'
            WHEN patient_sat_score BETWEEN 4 AND 7 THEN 'MEDIUM'
            ELSE 'LOW'
        END AS dissatisfaction_level,
        ROW_NUMBER() OVER (
            PARTITION BY 
                CASE
                    WHEN patient_sat_score > 7 THEN 'HIGH'
                    WHEN patient_sat_score BETWEEN 4 AND 7 THEN 'MEDIUM'
                    ELSE 'LOW'
                END
            ORDER BY patient_sat_score
        ) AS rn
    FROM er_patients
)
SELECT 
    patient_id,
    Age_Group,
    patient_sat_score,
    dissatisfaction_level
FROM categorized_scores
WHERE rn <= 5
ORDER BY dissatisfaction_level, rn;

-- Q7: Recommend departments for hiring
SELECT department_referral, COUNT(*) AS patient_count,
       ROUND(AVG(patient_waittime), 2) AS avg_wait_time
FROM er_patients
GROUP BY department_referral
ORDER BY patient_count DESC, avg_wait_time DESC
LIMIT 3;

-- Q8: Hospital profitability
SELECT SUM(Total_Bill) AS total_revenue,
       COUNT(DISTINCT patient_id) AS total_patients,
       ROUND(SUM(Total_Bill) / COUNT(DISTINCT patient_id), 2) AS revenue_per_patient
FROM er_doctor;

-- Q9: Department with highest waiting time
SELECT department_referral, ROUND(AVG(patient_waittime), 2) AS avg_wait_time
FROM er_patients
GROUP BY department_referral
ORDER BY avg_wait_time DESC
LIMIT 1;

-- Q10: Patients eligible for discounts
WITH categorized_discounts AS (
    SELECT 
        patient_id, 
        department_referral, 
        patient_waittime, 
        patient_sat_score,
        CASE
            WHEN patient_waittime >= 50 AND patient_sat_score <= 3 THEN 'High Discount'
            WHEN patient_waittime >= 40 AND patient_sat_score <= 5 THEN 'Medium Discount'
            WHEN patient_waittime >= 30 AND patient_sat_score <= 6 THEN 'Low Discount'
            ELSE 'No Discount'
        END AS discount_category
    FROM er_patients
),
ranked_patients AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY discount_category ORDER BY patient_waittime DESC) AS rn
    FROM categorized_discounts
    WHERE discount_category IN ('High Discount', 'Medium Discount', 'Low Discount')
)
SELECT 
    discount_category, count(*) as count
FROM ranked_patients
group by discount_category
ORDER BY discount_category;

-- Q11: General Practice doctor shift allocation
SELECT 
    CASE
        WHEN HOUR(visit_time) BETWEEN 6 AND 14 THEN 'Shift A'
        WHEN HOUR(visit_time) BETWEEN 15 AND 23 THEN 'Shift B'
        ELSE 'Off-hours'
    END AS shift,
    COUNT(*) AS visit_count
FROM er_patients ep
JOIN er_doctor ed ON ep.patient_id = ed.patient_id
WHERE ep.department_referral = 'General Practice'
GROUP BY shift
ORDER BY shift;


-- Q14: Doctor-Department relationship
SELECT Doctor_ID,
       COUNT(DISTINCT department_referral) AS dept_count
FROM er_doctor
GROUP BY Doctor_ID
ORDER BY dept_count DESC;
