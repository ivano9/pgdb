SELECT 
nsp.nspname, description  
FROM pg_namespace nsp 
LEFT OUTER JOIN pg_description des ON des.objoid=nsp.oid  
WHERE pg_get_userbyid(nspowner) = current_user AND nsp.nspname = '$id'
ORDER BY nspname