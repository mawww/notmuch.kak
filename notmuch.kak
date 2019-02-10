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

    set-option global notmuch_last_search %arg{1} 

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
        execute-keys '%'
        notmuch-apply-to part 'Content-type: text/html$' %{
            execute-keys 'K<a-;>J<a-x>' '|w3m -dump -T text/html -o display_link_number=true<ret>'
        }

        notmuch-apply-to header '' %{execute-keys <a-S><a-x>d<a-space>j<a-x>d}
        notmuch-apply-to body '' %{execute-keys <a-S><a-x>d}

        notmuch-apply-to part 'Content-type: multipart/alternative$' %{
        }

        notmuch-apply-to part '' %[
            execute-keys -draft 'K<a-;>J<a-x><gt>'
            execute-keys <a-S>
            execute-keys -draft <space><a-x>d
            execute-keys -draft <a-space><a-x>s\fpart\{<ret>c ' ⬜ Part: ' <esc>o<esc>
        ]
        notmuch-apply-to message '' %{
            execute-keys -draft 'K<a-;>J<a-x><gt>'
            execute-keys -draft ';<a-x>c<ret>'
            execute-keys -draft '<a-;>;<a-x>s' id:\S+ <ret>"ay <a-x>Hc ' ⬜ Message: <c-r>a<ret>' <esc>
        }
    ]

    add-highlighter buffer/ regex ^\h*(From|To|Cc|Bcc|Subject|Reply-To|In-Reply-To|Date):([^\n]*)$ 1:keyword 2:attribute
    add-highlighter buffer/ regex <[^@>]+@.*?> 0:string
    add-highlighter buffer/ regex ^\h*>.*?$ 0:comment

    add-highlighter buffer/ wrap -indent -word -marker ' ->'
]
