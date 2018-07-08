Bulk generation
1) Update database
	- Make sure all PID keys in natural_accepted and natural_hybrids are current. 
	- Hybrid type = 'hybrid', Accepted type = 'species', status must not be 'synonym'

2) Generate family trees:
	- Run genTree2Files_bulk.pl.  
	- This script reads from natural_hybrid table and generates family trees in to files.  

3) Generate ancestor-descendant pairs:
	- make a copy of natural_ancestordescendant table and empty table.
	- Run genAncDscPairs_bulk.pl.
		- reads from putput files from step 2)
		- extracts ancestor-descendent pairs and compute ancestor%, number of total ancestors and species ancestor, 
		- insert into natural_sancestordescendant table and also to files.
	- Output:
		- insert ancestor% into ancestor-descendant table, also output to files
		- output total number of ancestores and species type ancestors into a single file: ancestor_count.database
		- Load this filke into accepted and hybrid tables.

4) Descendant count for a species or a hybrid:  
	- Query number of descendants of a species or a hybrid from ancestor_descendant table.  
	- Update the anc_num and desc_num in Accepted and Hybrid tables (update num img_anc_desc.sql)
		
			
		
Update
5) New hybrid.  (Either run gen_ancdescPairs.pl or  do this manually for small tree)
	- Run gen_ancdescPairs.pl to create ancestor tree for the new hybrid 
		- For each new hybrid (pid) create a hash array %combo (or insert to AncestorDescendant table)
			1. Insert primary nodes (did, seed id, 50%) and (did, pollen id, 50%)
			2. Query seed tree from AncestorDescendant table { (seed id, aid, pct%)} 
			3. Replace seed id by the new hybrid id (pid) and devide pct% by 2 to get {(pid, aid, pct%/2)} and insert to table
			4. Query pollen tree from AncestorDescendant table { (pollen id, aid, pct%)( }. Replace pollen id with the new pid and divide pct by 2.
			5. Loop through pollen tree 
				- if the current node doesn't exist, insert to table.
				- if the current node already exist, add pct%/2 to the existing node
				
Note: perform this update each at RHS refresh. I.e. in the last step in RHS refresh process, run gen_ancdescPairs.pl.

6) Ancestor and descendant counts, depth of trees


