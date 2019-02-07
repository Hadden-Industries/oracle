CREATE OR REPLACE
PROCEDURE FCOPY_BINARY
(
    src_location    IN VARCHAR2,
    src_filename    IN VARCHAR2,
    dest_location   IN VARCHAR2,
    dest_filename   IN VARCHAR2
)
AS
    
   in_file UTL_FILE.file_type;
   out_file UTL_FILE.file_type;
   buffer_size CONSTANT PLS_INTEGER := 32767;
   buffer RAW(32767);
   buffer_length PLS_INTEGER;
   
BEGIN
   -- Open a handle to the location where you are going to read the Text or Binary file from
   -- NOTE: The 'rb' parameter means "read in byte mode" and is only available
   --       in the UTL_FILE package with Oracle 10g or later
   in_file := UTL_FILE.fopen(src_location, src_filename, 'rb', buffer_size);
   -- Open a handle to the location where you are going to write the Text or Binary file to
   -- NOTE: The 'wb' parameter means "write in byte mode" and is only available
   --       in the UTL_FILE package with Oracle 10g or later
   out_file := UTL_FILE.fopen(dest_location, dest_filename, 'wb', buffer_size);
   -- Attempt to read the first chunk of the in_file
   UTL_FILE.get_raw(in_file, buffer, buffer_size);
   -- Determine the size of the first chunk read
   buffer_length := UTL_RAW.LENGTH(buffer);

   -- Only write the chunk to the out_file if data exists
   WHILE buffer_length > 0
   LOOP
      -- Write one chunk of data
      UTL_FILE.put_raw(out_file, buffer, TRUE);

      -- Read the next chunk of data
      IF buffer_length = buffer_size
      THEN
         -- Buffer was full on last read, read another chunk
         UTL_FILE.get_raw(in_file, buffer, buffer_size);
         -- Determine the size of the current chunk
         buffer_length := UTL_RAW.LENGTH(buffer);
      ELSE
         buffer_length := 0;
      END IF;
   END LOOP;

   -- Close the file handles
   UTL_FILE.fclose(in_file);
   UTL_FILE.fclose(out_file);
EXCEPTION
   -- Raised when the size of the file is a multiple of the buffer_size
   WHEN NO_DATA_FOUND
   THEN
      -- Close the file handles
      UTL_FILE.fclose(in_file);
      UTL_FILE.fclose(out_file);
END;
/

GRANT EXECUTE ON FCOPY_BINARY TO SYSTEM;