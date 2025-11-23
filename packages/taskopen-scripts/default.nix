{
  writeShellScriptBin,
  buildEnv
}: let
  addnote = writeShellScriptBin "addnote" /*bash*/''
    # Annotates a task with 'Notes.<ext>'.

    # REQUIRES: awk

    DEFAULT_EXT="md"

    # Only add an annotation if we are operating on a single ID
    if [ $# -eq 1 ]; then
        desc=$(task $1 info | awk '$0 ~ /^Description/ {print substr($0, index($0,$2))}')
        echo "Attaching to task $1 '$desc'."
        echo -n "Type a file extension (or none for default=$DEFAULT_EXT): "
        read ext
        ann=""
        if [ "$ext" != "" ]; then
            ann="Notes.$ext"
        else
            ann="Notes.$DEFAULT_EXT"
        fi
        task $1 annotate -- $ann
    fi
  '';

  editnote = writeShellScriptBin "editnote" /*bash*/''
    # Opens a Notes file and creates a header if file does not exist.

    # Usage
    if [ $# -eq 3 ]; then
      if [ ! -e $1 ]; then
        filename=$(basename -- "$1")
        extension="''${filename##*.}"

        case $extension in
          md)
            echo "# $2" > $1
            echo "<!-- \$id{$3} -->" >> $1
          ;;

          org)
            echo "* $2" > $1
            echo "# \$id{$3}" >> $1
          ;;

          *)
            echo "$2" > $1
            echo "\$id{$3}" >> $1
          ;;
        esac
      fi

      $EDITOR $1
    else
      echo "Usage: $0 <file-path> <description> <uuid>"
    fi
  '';
in
  # Combine scripts to a single package.
  buildEnv {
    name = "taskopen-scripts";
    paths = [addnote editnote];
  }
