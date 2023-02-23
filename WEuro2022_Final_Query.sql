--First I am cleaning all tables to include the calculations I want and then creating CTE's to join all clean tables together.
;WITH complete_passes (p_player, player_assists, player_chances_created, p_team, team_assists, team_chances_created)



AS

(
-- Here I am cleaning the passess table to create seperate columns for assists and chances created. I also make the same calculations for all teams as a seperate table and join both individual player and team calculations.

-- Passes (Chances) created by player
SELECT pp.player AS p_player, SUM(clean_goal) AS player_assists, SUM(clean_shot_assist) AS player_chances_created, tp.team AS p_team, tp.team_assists AS team_assists, tp.team_chances_created AS team_chances_created

FROM
(SELECT player, team,

CASE
WHEN outcome  IS  NULL THEN 'Complete'
WHEN outcome = 'Incomplete' THEN 'Incomplete'
WHEN outcome = 'Injury Clearance' THEN 'Injury Clearance'
WHEN outcome = 'Out' THEN 'Out'
WHEN outcome = 'Pass Offside' THEN 'Pass Offside'
WHEN outcome = 'Unknown' THEN 'Unknown'
ELSE NULL
END AS pass_outcome,

CASE
WHEN shot_assist IS NULL THEN 0
WHEN shot_assist = 1 THEN 1
ELSE 0
END AS clean_shot_assist,

CASE
WHEN goal_assist IS NULL THEN 0
WHEN goal_assist = 1 THEN 1
ELSE 0
END AS clean_goal

FROM [Portfolio Projects].dbo.weuro_passes
) pp

LEFT JOIN

(--Team Passes (Chances Created)
SELECT team, SUM(clean_goal) AS team_assists, SUM(clean_shot_assist) AS team_chances_created

FROM


(SELECT player, team,

CASE
WHEN outcome  IS  NULL THEN 'Complete'
WHEN outcome = 'Incomplete' THEN 'Incomplete'
WHEN outcome = 'Injury Clearance' THEN 'Injury Clearance'
WHEN outcome = 'Out' THEN 'Out'
WHEN outcome = 'Pass Offside' THEN 'Pass Offside'
WHEN outcome = 'Unknown' THEN 'Unknown'
ELSE NULL
END AS pass_outcome,

CASE
WHEN shot_assist IS NULL THEN 0
WHEN shot_assist = 1 THEN 1
ELSE 0
END AS clean_shot_assist,

CASE
WHEN goal_assist IS NULL THEN 0
WHEN goal_assist = 1 THEN 1
ELSE 0
END AS clean_goal


FROM [Portfolio Projects].dbo.weuro_passes
) sub1

GROUP BY team


) AS tp ON tp.team = pp.team



GROUP BY tp.team, pp.player, tp.team_assists, tp.team_chances_created

--ORDER BY tp.team_chances_created DESC

)

, complete_shots

AS

(

--Player and team shots

SELECT DISTINCT ps.player AS s_player, COUNT(outcome) AS player_shots,  ts.team AS s_team, ts.team_shots,ts.team_goals,
SUM(CASE
WHEN outcome = 'Goal' THEN 1
ELSE 0
END) AS goals

FROM [Portfolio Projects].dbo.weuro_shots as ps

LEFT JOIN 

(SELECT team, COUNT(*) AS team_shots,
SUM(CASE
WHEN outcome = 'goal' THEN 1
ELSE 0
END) AS team_goals
	
FROM [Portfolio Projects].dbo.weuro_shots

GROUP BY team

) AS ts ON ts.team = ps.team 


GROUP BY ps.player, ts.team, ts.team_shots, ts.team_goals

--ORDER BY ts.team_shots DESC

)
, complete_dribbles

AS

(
--Player and team dribbles 

(SELECT player AS d_player, SUM(complete_dribbles) AS total_complete_dribbles, SUM(incomplete_dribbles) AS total_incomplete_dribbles, td.team AS d_team, td.total_team_complete_dribbles AS total_team_complete_dribbles, td.total_team_incomplete_dribbles AS total_team_incomplete_dribbles
FROM

(SELECT player, team, 

CASE
WHEN outcome IS NULL THEN 0
WHEN outcome =  'Complete' THEN 1
ELSE 0
END AS complete_dribbles,

CASE 
WHEN outcome IS NULL THEN 0
WHEN outcome = 'Incomplete' THEN 1
ELSE 0
END AS incomplete_dribbles

FROM [Portfolio Projects].dbo.weuro_dribbles

)pd

LEFT JOIN

(SELECT team, SUM(complete_dribbles) AS total_team_complete_dribbles, SUM(incomplete_dribbles) AS total_team_incomplete_dribbles
FROM

(SELECT player, team, 

CASE
WHEN outcome IS NULL THEN 0
WHEN outcome =  'Complete' THEN 1
ELSE 0
END AS complete_dribbles,

CASE 
WHEN outcome IS NULL THEN 0
WHEN outcome = 'Incomplete' THEN 1
ELSE 0
END AS incomplete_dribbles

FROM [Portfolio Projects].dbo.weuro_dribbles

)clean_dribbles
GROUP BY team

) AS td ON td.team = pd.team

GROUP BY pd.player, td.team, td.total_team_complete_dribbles, td.total_team_incomplete_dribbles 
)

)
--Cleaning disposession table to sum total number of miscontrols and disposessions grouped by players and creating the same calculations, but grouped by teams. 
, dposess

AS

(

SELECT tdis.dis_team, player AS dis_player, team_disposessions, team_miscontrol,
SUM(CASE
WHEN disposession = 'Dispossessed' THEN 1
ELSE 0
END) AS disposessions,

SUM(CASE
WHEN miscontrol = 'Miscontrol' THEN 1
ELSE 0
END) AS miscontrol

FROM [Portfolio Projects].dbo.dpossess AS pds

LEFT JOIN (SELECT team AS dis_team,

			SUM(CASE
				WHEN disposession = 'Dispossessed' THEN 1
				ELSE 0
				END) AS team_disposessions,

			SUM(CASE
				WHEN miscontrol = 'Miscontrol' THEN 1
				ELSE 0
				END) AS team_miscontrol

				FROM [Portfolio Projects].dbo.dpossess
				GROUP BY team
				) AS tdis ON tdis.dis_team = pds.team

				GROUP BY tdis.dis_team, pds.player, tdis.team_disposessions, tdis.team_miscontrol



)
-- I combine all the CTE's and insert the query into it's own table.
INSERT INTO dbo.s_combined
		SELECT p_player, p_team, player_assists, player_chances_created, team_assists, team_chances_created, total_complete_dribbles, total_incomplete_dribbles, total_team_complete_dribbles, total_team_incomplete_dribbles, player_shots, team_shots, goals, team_goals, disposessions, team_disposessions, miscontrol, team_miscontrol 
		FROM complete_passes AS cpass
		LEFT JOIN complete_dribbles AS cdrib ON cdrib.d_team = cpass.p_team AND cdrib.d_player = cpass.p_player
		LEFT JOIN complete_shots AS cshots ON cshots.s_team = cdrib.d_team AND cshots.s_player = cdrib.d_player
		LEFT JOIN dposess AS dpos ON dpos.dis_team = cshots.s_team AND dpos.dis_player = cshots.s_player
		


		
--Created the "combined" table here.		
DROP TABLE IF EXISTS dbo.s_combined
		
CREATE TABLE dbo.s_combined

(	p_player nvarchar(256), 
	p_team nvarchar(256),
	player_assists float, 
	player_chances_created float,
	team_assists float, 
	team_chances_created float,
	total_complete_dribbles float,
	total_incomplete_dribbles float,
	total_team_complete_dribbles float,
	total_team_incomplete_dribbles float,
	player_shots float,
	team_shots float,
	goal float,
	team_goals float,
	disposessions float, 
	team_disposessions float,
	miscontrol float, 
	team_miscontrol float



 )




 --Testing the table using a select all statement

SELECT*



FROM dbo.s_combined

ORDER BY p_player

--Using UPDATE to turn any NULL values into 0

UPDATE dbo.s_combined

SET total_complete_dribbles = 0, total_incomplete_dribbles = 0, total_team_incomplete_dribbles = 0, total_team_complete_dribbles = 0, player_shots = 0, team_shots = 0

WHERE total_complete_dribbles IS NULL AND total_incomplete_dribbles IS NULL AND total_team_complete_dribbles IS NULL AND total_team_incomplete_dribbles IS NULL AND player_shots IS NULL AND team_shots IS NULL


SELECT * --((CAST(player_assists AS FLOAT) + CAST(player_chances_created AS FLOAT) + CAST(total_complete_dribbles AS FLOAT) + CAST(total_incomplete_dribbles AS FLOAT) + CAST(player_shots AS FLOAT))/(CAST(team_assists AS FLOAT) + CAST(team_chances_created AS FLOAT) + CAST(total_complete_dribbles AS FLOAT) + CAST(total_team_incomplete_dribbles AS FLOAT) + CAST(team_shots AS FLOAT))) * 100 AS usage_rate
	

FROM dbo.s_combined

UPDATE dbo.s_combined

SET player_shots = 0, team_shots = 0, goal = 0, team_goals = 0

WHERE player_shots IS NULL AND team_shots IS NULL AND goal IS NULL AND team_goals IS NULL

--Calculating the rates
SELECT p_player, ((CAST(player_assists AS FLOAT) + CAST(player_chances_created AS FLOAT) + CAST(total_complete_dribbles AS FLOAT) + CAST(total_incomplete_dribbles AS FLOAT) + CAST(player_shots AS FLOAT) + CAST(goal AS float))/(CAST(team_assists AS FLOAT) + CAST(team_chances_created AS FLOAT) + CAST(total_team_complete_dribbles AS FLOAT) + CAST(total_team_incomplete_dribbles AS FLOAT) + CAST(team_shots AS FLOAT)+CAST(team_goals AS float)) * 100 AS usage_rate, 
(SELECT player_assists + player_chances_created + player_shots + total_complete_dribbles + goal FROM dbo.s_combined)
	

FROM dbo.s_combined




UPDATE dbo.s_combined

SET goal = 0, team_goals = 0

WHERE goal IS NULL AND team_goals IS NULL

UPDATE dbo.s_combined
SET disposessions = 0, team_disposessions = 0, miscontrol = 0, team_miscontrol = 0

WHERE disposessions IS NULL AND team_disposessions IS NULL AND miscontrol IS NULL AND team_miscontrol IS NULL


--NULLIF returns a null value if it matches the value after the comma

-- Using NULLIF and IS NULL to turn any remaining NULL values to 0 

--Creating another table to place calculated data


INSERT INTO dbo.usage_rates

SELECT p_player, p_team, (player_assists + player_chances_created + total_complete_dribbles + total_incomplete_dribbles + player_shots + goal + miscontrol + disposessions)/(team_assists + team_chances_created + total_team_complete_dribbles + total_team_incomplete_dribbles + team_shots + team_goals + team_disposessions + team_miscontrol) * 100 AS usage_rate,
ISNULL((goal + player_assists + player_chances_created + player_shots)/NULLIF((player_assists + player_chances_created + total_complete_dribbles + total_incomplete_dribbles + player_shots + goal+ miscontrol + disposessions), 0),0) *100 AS positive_rate

FROM s_combined


DROP TABLE dbo.usage_rates
CREATE TABLE dbo.usage_rates

(
p_player nvarchar(256),
p_team nvarchar(256),
usage_rate float,
positive_rate float

)

--Creting a view for visualization tool
SELECT * 
FROM dbo.usage_rates

GO

CREATE VIEW dbo.fin AS

SELECT p_player, p_team, usage_rate, positive_rate

FROM dbo.usage_rates


DROP VIEW dbo.fin


