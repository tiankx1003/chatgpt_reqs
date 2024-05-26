# Generate Insert Statement

in shell script, I read file use `while IFS=$'\t' read -r ... ; do ... ;done < 'input_file'`, the input_file separated by '\t' has file many columns at least three, the number of columns can vary for each row, may five or four or ten.
then I call a function named 'gen_statement' in while body, I want all the column give to the function, and in the function, first and second column as key01 and key02, others as value,
I want traverse the values in `for` loop and print "key01,key02,value", how coding?

## input
the [hello.tsv](hello.tsv) as follows
```tsv
aa	bb	01	02
aa	cc	01	03
dd	aa	00
cc	bb	01	05	11
```

## expect output
I want print like this
```csv
aa,bb,01
aa,bb,02
aa,cc,01
aa,cc,03
dd,aa,00
cc,bb,01
cc,bb,05
cc,bb,11
```

* error output
```tsv
aa,bb,01        02
aa,cc,01        03
dd,aa,00
cc,bb,01        05      11
```

## Best Impl
```Bash
#!/bin/bash

function gen_statement {
    key01="$1"
    key02="$2"
    shift 2  # Remove the first two arguments (key01 and key02)
    for value in "$@"; do
        echo "$key01,$key02,$value"
    done
}

while IFS=$'\t' read -r -a columns; do
    key01="${columns[0]}"
    key02="${columns[1]}"
    gen_statement "$key01" "$key02" "${columns[@]:2}"
done < 'input_file'

```