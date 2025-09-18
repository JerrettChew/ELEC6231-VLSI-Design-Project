#! /bin/sh

if [ "$#" -gt 1 ]
then
  echo "\nERROR - too many arguments"
  echo "\nUsage: install_vmem  [<destimation_rom_file>]"
  exit
fi

rom_file="../behavioural/ahb_rom.sv"

if [ "$1" != "" ]
then
  rom_file="$1"
  shift
fi

  if [ ! -f "$rom_file" ]
  then
    printf "\nERROR - ROM file '$rom_file' not found\n"
  else
    if grep '^// BEGIN CUSTOM$' $rom_file > /dev/null &&
       grep '^// END CUSTOM$' $rom_file > /dev/null
    then
      printf "Creating custom ROM file\n"
      sed -e  '/^.. BEGIN CUSTOM$/,$ d' $rom_file > rom.sv
      printf "// BEGIN CUSTOM\n\n" >> rom.sv
      cat code.vmem >> rom.sv
      printf "\n// END CUSTOM\n" >> rom.sv
      sed -e  '1,/^.. END CUSTOM$/ d' $rom_file >> rom.sv
      if [ ! -e "${rom_file}_orig" ]
      then
        printf "Saving '$rom_file' as '${rom_file}_orig'\n"
        mv $rom_file ${rom_file}_orig
        printf "Writing '$rom_file'\n"
        mv rom.sv $rom_file
        printf "To recover orignal file type\n"
        printf "  mv ${rom_file}_orig $rom_file\n"
      else
        printf "Overwriting '$rom_file'\n"
        mv rom.sv $rom_file
      fi
      
    else
      printf "\nERROR - ROM file '$rom_file' seems to be missing expected comments\n"
    fi
  fi
