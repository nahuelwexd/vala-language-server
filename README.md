# Vala Language Server [![Gitter](https://badges.gitter.im/vala-language-server/community.svg)](https://gitter.im/vala-language-server/community)

![vls-vscode](images/vls-vscode.png)
![vls-vim](images/vls-vim.png)
![vls-gb](images/vls-gb.png)

## Contents
1. Features
2. Dependencies
3. Setup
    1. Building and Installing
    2. With Vim
    3. With Visual Studio Code
    4. With GNOME Builder
4. Contributing

### Features
- [x] diagnostics
- [x] code completion
    - [x] basic (member access and scope-visible completion)
    - [ ] advanced (context-sensitive suggestions)
    - completion support relies heavily on changes made upstream to the Vala parser. See [this MR](https://gitlab.gnome.org/GNOME/vala/-/merge_requests/95) if you want to build VLS with improved completion ability
- [x] document symbol outline
- [x] goto definition
- [x] symbol references
- [x] goto implementation
- [x] signature help
    - active parameter support requires upstream changes in vala and is disabled by default. use `meson -Dactive_parameter=true` to enable. see [this MR](https://gitlab.gnome.org/GNOME/vala/-/merge_requests/95)
- [x] hover
- [x] symbol documentation
    - [x] basic (from comments)
    - [x] advanced (from GIR and VAPI files)
        - this feature may be a bit unstable. If it breaks things, use `meson -Dparse_system_girs=false` to disable
- [x] search for symbols in workspace
- [x] highlight active symbol in document
- [ ] snippets
- [ ] code actions
- [ ] workspaces
- [ ] supported IDEs (see Setup below):
    - [x] vim with `vim-lsp` plugin installed
    - [x] Visual Studio Code
    - [x] GNOME Builder >= 3.35
    - [ ] IntelliJ
- [ ] supported project build systems
    - [x] meson
    - [ ] autotoools
    - [ ] cmake

### Dependencies
- `glib-2.0`
- `gobject-2.0`
- `gio-2.0` and either `gio-unix-2.0` or `gio-windows-2.0`
- `gee-0.8`
- `jsonrpc-glib-1.0`
- `libvala-0.48` or later
    - you MUST compile with vala master from commit `f8676a6584d5b67ac76e132061a9df5d92258b0f` or later

### Setup

#### Building and Installing
```
$ meson -Dprefix=$PREFIX build
$ ninja -C build
$ sudo ninja -C build install
```

This will install `vala-language-server` to `$PREFIX/bin`

#### With Vim
Once you have VLS installed, you can use it with `vim`.

1. Make sure [vim-lsp](https://github.com/prabirshrestha/vim-lsp) is installed
2. Add the following to your `.vimrc`:

```vim
if executable('vala-language-server')                     
  au User lsp_setup call lsp#register_server({              
        \ 'name': 'vala-language-server',
        \ 'cmd': {server_info->[&shell, &shellcmdflag, 'vala-language-server']}, 
        \ 'whitelist': ['vala'],
        \ })
endif
```

#### With Visual Studio Code
- Install the Vala plugin (https://marketplace.visualstudio.com/items?itemName=prince781.vala)

#### With GNOME Builder
- Support is currently available with Builder 3.35 and up
- Running `ninja -C build install` should install the plugin to `$PREFIX/lib/gnome-builder/plugins`. Make sure you disable the GVLS plugin.

### Contributing
Want to help out? Here are some helpful resources:

- If you're a newcomer, check out https://github.com/benwaffle/vala-language-server/issues?q=is%3Aissue+is%3Aopen+label%3Anewcomers
- Gitter room is for project discussions: https://gitter.im/vala-language-server/community
- `#vala` on gimpnet/IRC is for general discussions about Vala and collaboration with upstream
- Vala wiki: https://wiki.gnome.org/Projects/Vala/
- libvala documentation:
    - https://benwaffle.github.io/vala-language-server/index.html
    - https://gnome.pages.gitlab.gnome.org/vala/docs/index.html
