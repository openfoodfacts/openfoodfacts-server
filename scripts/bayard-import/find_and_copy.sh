find /home/sftp/equadis/data/ -mtime -5 -type f -exec grep -q 'NATURENVIE' {} \; -exec cp {} /srv2/off-pro/equadis-data-tmp/ \;
