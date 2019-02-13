declare-option str notmuch_thread_client
declare-option str notmuch_last_search

define-command notmuch -params 1.. \
    -shell-script-candidates %{printf '%s\n' $kak_opt_notmuch_last_search} \
%{
    edit! -scratch *notmuch*
    execute-keys "!notmuch search %arg{@}<ret>gg"
    add-highlighter buffer/ line '%val{cursor_line}' default+r
    add-highlighter buffer/ regex \
        '^(?<thread>thread:[0-9a-f]+) +(?<date>[^[]+) (?<count>\[\d+/\d+\]) (?<names>[^;]*); (?<subject>[^\n]*) (?<tags>\([\w ]+\))$' \
        thread:yellow date:blue count:cyan names:green tags:red

    set-option buffer scrolloff 3,0
    set-option buffer notmuch_last_search %arg{1}

    hook buffer NormalIdle .* %{ evaluate-commands -draft %{
        execute-keys <a-x>sthread:\S+<ret>
        evaluate-commands -try-client %opt{notmuch_thread_client} notmuch-thread %val{selection}
    }}
}

define-command notmuch-update %{
    notmuch %opt{notmuch_last_search}
}

define-command notmuch-apply-to -params 3 %[ evaluate-commands -draft %[ try %[
    execute-keys s "\f%arg{1}\{" <ret> <a-x><a-k> "%arg{2}" <ret>
    evaluate-commands -itersel %[
        execute-keys }c "\f%arg{1}\{,\f%arg{1}\}" <ret>
        evaluate-commands %arg{3}
    ]
]]]

define-command notmuch-thread -params 1 %[
    edit! -scratch *notmuch-thread*
    execute-keys "!notmuch show --include-html --format=text %arg{@}<ret>gg"
    set-option buffer indentwidth 2
    evaluate-commands -draft %[
        try %[ execute-keys \%s [^\n]\f\w+[{}] <ret> '<a-;>;a<ret><esc>' ] # Ensure all markers are on their own line
        execute-keys '%'
        notmuch-apply-to part 'Content-type: multipart/(mixed|related)$' %{
            execute-keys <a-S><a-x>d
        }
        notmuch-apply-to part 'Content-type: multipart/alternative$' %{
            evaluate-commands -draft %[
                execute-keys 'K<a-;>J<a-x><a-:>'
                execute-keys s \fpart\{ <ret> }c \fpart\{,\fpart\} <ret>
                execute-keys -draft <a-k> '\A[^\n]+Content-type: text/html$' <ret>  # Ensure we have a text/html part
                execute-keys -draft <a-K> '\A[^\n]+Content-type: text/html$' <ret><a-x>d # Remove other parts
            ]
            execute-keys <a-S><a-x>d
        }
        notmuch-apply-to part 'Content-type: text/html$' %{
            execute-keys 'K<a-;>J<a-x>' '|w3m -dump -T text/html -o display_link_number=true<ret>'
        }
        notmuch-apply-to header '' %[
            execute-keys <a-S><a-x>d<a-space>j<a-x>d
        ]
        notmuch-apply-to body '' %[
            execute-keys <a-S><a-x>d
        ]
        notmuch-apply-to part '' %[
            execute-keys -draft '<a-;>J<gt>'
            execute-keys -draft <a-S><space><a-x>d
            execute-keys -draft <a-S><a-space><a-x>s\fpart\{<ret>c '⬛ Part:' <esc>
        ]
        notmuch-apply-to attachment '' %[
            execute-keys -draft '<a-;>J<a-x>d'
            execute-keys -draft <a-x>s\fattachment\{<ret>c '⬛ Attachment:' <esc>
        ]
        notmuch-apply-to message '' %{
            execute-keys -draft 'K<a-;>J<a-x><gt>'
            execute-keys -draft ';<a-x>c<ret>'
            execute-keys -draft '<a-;>;<a-x>s' id:\S+ <ret>"ay <a-x>Hc '⬛ Message: <c-r>a' <esc>
        }
    ]

    add-highlighter buffer/ regex ^\h*(From|To|Cc|Bcc|Subject|Reply-To|In-Reply-To|Date):([^\n]*)$ 1:keyword 2:attribute
    add-highlighter buffer/ regex <[^@>]+@.*?> 0:string
    add-highlighter buffer/ regex ^\h*>.*?$ 0:comment

    add-highlighter buffer/ wrap -indent -word -marker ' ➥'
]

define-command notmuch-save-part %{
    try %{
        evaluate-commands -save-regs abc %{
            evaluate-commands -draft %{
                execute-keys gl<a-/> '⬛ (?:Part|Attachment): ID: (\d+)[^\n]+?(?:Filename: ([^\n,]+))?(?:,|$)' <ret>
                set-register a %reg{1}
                set-register b %reg{2}
                execute-keys gl<a-/> '⬛ (?:Message): (id:\S+)' <ret>
                set-register c %reg{1}
            }
            prompt "save part %reg{a} of message %reg{c} to: " -init "%reg{b}" \
                   "nop %%sh{ notmuch show --part %reg{a} %reg{c} > ""$kak_text"" }"
        }
    } catch %{
        echo -markup "{Error}Could not determine current part and message"
    }
}
