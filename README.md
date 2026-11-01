# General Testing Convention (GTC)

**General Testing Convention (GTC) is a rewritten, better version of [vUNC](https://github.com/Veaquach/unified-naming-convention) (veaquach's Unified Naming Convention, now deprecated) that aims to bring executor testing together in one easy and fast script.**

## What it has

- **136 tests**, with more possibly coming soon.
- Clear descriptions for all functions, plus the reason each test passed or failed.
- **Downsides** - 6 checks, including internality, RakNet, identity spoofing, and more.

## Upgrades from vUNC

- Internality is reported as a downside instead of being used to pass or fail a test without checking functionality.
- 63 more functions, without increasing test time (GTC takes ~0.35s, vUNC ~0.33s).

## Usage

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/Veaquach/GeneralTestingConvention/Test.luau"))()
```

After running, open your console (**F9** on PC or **/console** on mobile).

## Tested on

Made and tested on [Lucid](https://getlucid.gg), with Solara used for the bad-executor tests.


| Script | Tests | Time |
| --- | ---: | ---: |
| [GTC](https://github.com/Veaquach/GeneralTestingConvention/Test.luau) | 136 | ~0.35s |
| [vUNC](https://github.com/Veaquach/unified-naming-convention/vunc.luau) | 80 | ~0.33s |
| [sUNC](https://sunc.io) | 86 | ~15s |

<sub>*All times measured on [Lucid](https://getlucid.gg). The sUNC time comes from Lucid's published sUNC results via [WEAO](https://weao.xyz).*</sub>
