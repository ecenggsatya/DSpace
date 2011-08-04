-- Convert workflow groups:
-- TODO: is 'to_number' ok? do not forget to change role_id values

INSERT INTO xmlwf_collectionrole (role_id, group_id, collection_id)
SELECT
'reviewer' AS role_id,
eperson_group_id AS group_id,
to_number(replace(replace(name, 'COLLECTION_', ''), '_WORKFLOW_STEP_1', '')) AS collection_id
FROM epersongroup
WHERE name LIKE 'COLLECTION_%_WORKFLOW_STEP_1';

INSERT INTO xmlwf_collectionrole  (role_id, group_id, collection_id)
SELECT
'editor' AS role_id,
eperson_group_id AS group_id,
to_number(replace(replace(name, 'COLLECTION_', ''), '_WORKFLOW_STEP_2', '')) AS collection_id
FROM epersongroup
WHERE name LIKE 'COLLECTION_%_WORKFLOW_STEP_2';

INSERT INTO xmlwf_collectionrole  (role_id, group_id, collection_id)
SELECT
'finaleditor' AS role_id,
eperson_group_id AS group_id,
to_number(replace(replace(name, 'COLLECTION_', ''), '_WORKFLOW_STEP_3', '')) AS collection_id
FROM epersongroup
WHERE name LIKE 'COLLECTION_%_WORKFLOW_STEP_3';


-- Migrate workflow items
INSERT INTO xmlwf_workflowitem (workflowitem_id, item_id, collection_id, multiple_titles, published_before, multiple_files)
SELECT
workflow_id AS workflowitem_id,
item_id,
collection_id,
multiple_titles,
published_before,
multiple_files
FROM workflowitem;


-- Migrate claimed tasks
INSERT INTO xmlwf_claimtask (workflowitem_id, workflow_id, step_id, action_id, owner_id)
SELECT
workflow_id AS workflowitem_id,
'default' AS workflow_id,
'reviewstep' AS step_id,
'reviewaction' AS action_id,
owner AS owner_id
FROM workflowitem WHERE owner IS NOT NULL AND state = 2;

INSERT INTO xmlwf_claimtask (workflowitem_id, workflow_id, step_id, action_id, owner_id)
SELECT
workflow_id AS workflowitem_id,
'default' AS workflow_id,
'editstep' AS step_id,
'editaction' AS action_id,
owner AS owner_id
FROM workflowitem WHERE owner IS NOT NULL AND state = 4;

INSERT INTO xmlwf_claimtask (workflowitem_id, workflow_id, step_id, action_id, owner_id)
SELECT
workflow_id AS workflowitem_id,
'default' AS workflow_id,
'finaleditstep' AS step_id,
'finaleditaction' AS action_id,
owner AS owner_id
FROM workflowitem WHERE owner IS NOT NULL AND state = 6;


-- Migrate pooled tasks
INSERT INTO xmlwf_pooltask (workflowitem_id, workflow_id, step_id, action_id, group_id)
SELECT
workflowitem.workflow_id AS workflowitem_id,
'default' AS workflow_id,
'reviewstep' AS step_id,
'claimaction' AS action_id,
xmlwf_collectionrole.group_id AS group_id
FROM workflowitem INNER JOIN xmlwf_collectionrole ON workflowitem.collection_id = xmlwf_collectionrole.collection_id
WHERE workflowitem.owner IS NULL AND workflowitem.state = 1 AND xmlwf_collectionrole.role_id = 'reviewer';

INSERT INTO xmlwf_pooltask (workflowitem_id, workflow_id, step_id, action_id, group_id)
SELECT
workflowitem.workflow_id AS workflowitem_id,
'default' AS workflow_id,
'editstep' AS step_id,
'claimaction' AS action_id,
xmlwf_collectionrole.group_id AS group_id
FROM workflowitem INNER JOIN xmlwf_collectionrole ON workflowitem.collection_id = xmlwf_collectionrole.collection_id
WHERE workflowitem.owner IS NULL AND workflowitem.state = 3 AND xmlwf_collectionrole.role_id = 'editor';

INSERT INTO xmlwf_pooltask (workflowitem_id, workflow_id, step_id, action_id, group_id)
SELECT
workflowitem.workflow_id AS workflowitem_id,
'default' AS workflow_id,
'finaleditstep' AS step_id,
'claimaction' AS action_id,
xmlwf_collectionrole.group_id AS group_id
FROM workflowitem INNER JOIN xmlwf_collectionrole ON workflowitem.collection_id = xmlwf_collectionrole.collection_id
WHERE workflowitem.owner IS NULL AND workflowitem.state = 5 AND xmlwf_collectionrole.role_id = 'finaleditor';

-- Create policies for claimtasks
--     public static final int BITSTREAM = 0;
--     public static final int BUNDLE = 1;
--     public static final int ITEM = 2;

--     public static final int READ = 0;
--     public static final int WRITE = 1;
--     public static final int DELETE = 2;
--     public static final int ADD = 3;
--     public static final int REMOVE = 4;
-- Item
-- TODO: getnextID == SELECT sequence.nextval FROM DUAL!!
-- Create a temporarty table with action ID's
CREATE TABLE temptable(
  action_id INTEGER PRIMARY KEY
)
INSERT ALL
  INTO temptable (action_id) VALUES (0)
  INTO temptable (action_id) VALUES (1)
  INTO temptable (action_id) VALUES (2)
  INTO temptable (action_id) VALUES (3)
  INTO temptable (action_id) VALUES (4)
SELECT * FROM DUAL;

INSERT INTO resourcepolicy (policy_id, resource_type_id, resource_id, action_id, eperson_id)
SELECT
resourcepolicy_seq.nextval AS policy_id,
2 AS resource_type_id,
xmlwf_workflowitem.item_id AS resource_id,
temptable.action_id AS action_id,
xmlwf_claimtask.owner_id AS eperson_id
FROM (xmlwf_workflowitem INNER JOIN xmlwf_claimtask ON xmlwf_workflowitem.workflowitem_id = xmlwf_claimtask.workflowitem_id),
temptable;

-- Bundles
INSERT INTO resourcepolicy (policy_id, resource_type_id, resource_id, action_id, eperson_id)
SELECT
resourcepolicy_seq.nextval AS policy_id,
1 AS resource_type_id,
item2bundle.bundle_id AS resource_id,
temptable.action_id AS action_id,
xmlwf_claimtask.owner_id AS eperson_id
FROM
(
	(xmlwf_workflowitem INNER JOIN xmlwf_claimtask ON xmlwf_workflowitem.workflowitem_id = xmlwf_claimtask.workflowitem_id)
	INNER JOIN item2bundle ON xmlwf_workflowitem.item_id = item2bundle.item_id
), temptable;


-- Bitstreams
INSERT INTO resourcepolicy (policy_id, resource_type_id, resource_id, action_id, eperson_id)
SELECT
resourcepolicy_seq.nextval AS policy_id,
0 AS resource_type_id,
bundle2bitstream.bitstream_id AS resource_id,
temptable.action_id AS action_id,
xmlwf_claimtask.owner_id AS eperson_id
FROM
(
	((xmlwf_workflowitem INNER JOIN xmlwf_claimtask ON xmlwf_workflowitem.workflowitem_id = xmlwf_claimtask.workflowitem_id)
	INNER JOIN item2bundle ON xmlwf_workflowitem.item_id = item2bundle.item_id)
	INNER JOIN bundle2bitstream ON item2bundle.bundle_id = bundle2bitstream.bundle_id
), temptable;


-- Create policies for pooled tasks

INSERT INTO resourcepolicy (policy_id, resource_type_id, resource_id, action_id, epersongroup_id)
SELECT
resourcepolicy_seq.nextval AS policy_id,
2 AS resource_type_id,
xmlwf_workflowitem.item_id AS resource_id,
temptable.action_id AS action_id,
xmlwf_pooltask.group_id AS epersongroup_id
FROM (xmlwf_workflowitem INNER JOIN xmlwf_pooltask ON xmlwf_workflowitem.workflowitem_id = xmlwf_pooltask.workflowitem_id),
temptable;

-- Bundles
INSERT INTO resourcepolicy (policy_id, resource_type_id, resource_id, action_id, epersongroup_id)
SELECT
resourcepolicy_seq.nextval AS policy_id,
1 AS resource_type_id,
item2bundle.bundle_id AS resource_id,
temptable.action_id AS action_id,
xmlwf_pooltask.group_id AS epersongroup_id
FROM
(
	(xmlwf_workflowitem INNER JOIN xmlwf_pooltask ON xmlwf_workflowitem.workflowitem_id = xmlwf_pooltask.workflowitem_id)
	INNER JOIN item2bundle ON xmlwf_workflowitem.item_id = item2bundle.item_id
), temptable;

-- Bitstreams
INSERT INTO resourcepolicy (policy_id, resource_type_id, resource_id, action_id, epersongroup_id)
SELECT
resourcepolicy_seq.nextval AS policy_id,
0 AS resource_type_id,
bundle2bitstream.bitstream_id AS resource_id,
temptable.action_id AS action_id,
xmlwf_pooltask.group_id AS epersongroup_id
FROM
(
	((xmlwf_workflowitem INNER JOIN xmlwf_pooltask ON xmlwf_workflowitem.workflowitem_id = xmlwf_pooltask.workflowitem_id)
	INNER JOIN item2bundle ON xmlwf_workflowitem.item_id = item2bundle.item_id)
	INNER JOIN bundle2bitstream ON item2bundle.bundle_id = bundle2bitstream.bundle_id
), temptable;

-- Drop the temporary table with the action ID's
DROP TABLE temptable;

-- Create policies for submitter
-- TODO: only add if unique
INSERT INTO resourcepolicy (policy_id, resource_type_id, resource_id, action_id, eperson_id)
SELECT
resourcepolicy_seq.nextval AS policy_id,
2 AS resource_type_id,
xmlwf_workflowitem.item_id AS resource_id,
0 AS action_id,
item.submitter_id AS eperson_id
FROM (xmlwf_workflowitem INNER JOIN item ON xmlwf_workflowitem.item_id = item.item_id);

INSERT INTO resourcepolicy (policy_id, resource_type_id, resource_id, action_id, eperson_id)
SELECT
resourcepolicy_seq.nextval AS policy_id,
1 AS resource_type_id,
item2bundle.bundle_id AS resource_id,
0 AS action_id,
item.submitter_id AS eperson_id
FROM ((xmlwf_workflowitem INNER JOIN item ON xmlwf_workflowitem.item_id = item.item_id)
      INNER JOIN item2bundle ON xmlwf_workflowitem.item_id = item2bundle.item_id
     );

INSERT INTO resourcepolicy (policy_id, resource_type_id, resource_id, action_id, eperson_id)
SELECT
resourcepolicy_seq.nextval AS policy_id,
0 AS resource_type_id,
bundle2bitstream.bitstream_id AS resource_id,
0 AS action_id,
item.submitter_id AS eperson_id
FROM (((xmlwf_workflowitem INNER JOIN item ON xmlwf_workflowitem.item_id = item.item_id)
      INNER JOIN item2bundle ON xmlwf_workflowitem.item_id = item2bundle.item_id)
      INNER JOIN bundle2bitstream ON item2bundle.bundle_id = bundle2bitstream.bundle_id
);

-- TODO: not tested yet
INSERT INTO xmlwf_in_progress_user (in_progress_user_id, workflowitem_id, step_id, user_id, finished)
SELECT
  xmlwf_in_progress_user_seq.nextval AS in_progress_user_id,
  xmlwf_workflowitem.item_id AS workflowitem_id,
  xmlwf_claimtask.owner_id AS user_id
  0 as finished
FROM
  (xmlwf_claimtask INNER JOIN xmlwf_workflowitem ON xmlwf_workflowitem.workflowitem_id = xmlwf_claimtask.workflowitem_id);

-- TODO: improve this, important is NVL(curr, 1)!! without this function, empty tables (max = [null]) will only result in sequence deletion
DECLARE
  curr  NUMBER := 0;
BEGIN
  SELECT max(workflowitem_id) INTO curr FROM xmlwf_workflowitem;

  curr := curr + 1;

  EXECUTE IMMEDIATE 'DROP SEQUENCE xmlwf_workflowitem_seq';

  EXECUTE IMMEDIATE 'CREATE SEQUENCE xmlwf_workflowitem_seq START WITH ' || NVL(curr, 1);
END;
/

DECLARE
  curr  NUMBER := 0;
BEGIN
  SELECT max(collectionrole_id) INTO curr FROM xmlwf_collectionrole;

  curr := curr + 1;

  EXECUTE IMMEDIATE 'DROP SEQUENCE xmlwf_collectionrole_seq';

  EXECUTE IMMEDIATE 'CREATE SEQUENCE xmlwf_collectionrole_seq START WITH ' || NVL(curr, 1);
END;
/

DECLARE
  curr  NUMBER := 0;
BEGIN
  SELECT max(workflowitemrole_id) INTO curr FROM xmlwf_workflowitemrole;

  curr := curr + 1;

  EXECUTE IMMEDIATE 'DROP SEQUENCE xmlwf_workflowitemrole_seq';

  EXECUTE IMMEDIATE 'CREATE SEQUENCE xmlwf_workflowitemrole_seq START WITH ' || NVL(curr, 1);
END;
/

DECLARE
  curr  NUMBER := 0;
BEGIN
  SELECT max(pooltask_id) INTO curr FROM xmlwf_pooltask;

  curr := curr + 1;

  EXECUTE IMMEDIATE 'DROP SEQUENCE xmlwf_pooltask_seq';

  EXECUTE IMMEDIATE 'CREATE SEQUENCE xmlwf_pooltask_seq START WITH ' || NVL(curr, 1);
END;
/

DECLARE
  curr  NUMBER := 0;
BEGIN
  SELECT max(claimtask_id) INTO curr FROM xmlwf_claimtask;

  curr := curr + 1;

  EXECUTE IMMEDIATE 'DROP SEQUENCE xmlwf_claimtask_seq';

  EXECUTE IMMEDIATE 'CREATE SEQUENCE xmlwf_claimtask_seq START WITH ' || NVL(curr, 1);
END;
/

DECLARE
  curr  NUMBER := 0;
BEGIN
  SELECT max(in_progress_user_id) INTO curr FROM xmlwf_in_progress_user;

  curr := curr + 1;

  EXECUTE IMMEDIATE 'DROP SEQUENCE xmlwf_in_progress_user_seq';

  EXECUTE IMMEDIATE 'CREATE SEQUENCE xmlwf_in_progress_user_seq START WITH ' || NVL(curr, 1);
END;
/