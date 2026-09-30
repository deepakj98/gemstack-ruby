# gemstack-http

**Merged into [`gemstack`](https://rubygems.org/gems/gemstack) in GemStack 0.3.0.**

This version is a transition shim: it depends on `gemstack` and loads `gemstack/http`, so Gemfiles that
still list `gemstack-http` keep working. To finish upgrading, remove `gem "gemstack-http"` from your Gemfile
(it's loaded by `require "gemstack"`).

GemStack is a modular Ruby API framework for Next.js applications by
[Adware Technologies](https://www.adwaretech.com) — [gemstack-rb/gemstack](https://github.com/gemstack-rb/gemstack).

## License

Open source under the MIT License — © [Adware Technologies](https://www.adwaretech.com). See [LICENSE.txt](LICENSE.txt).
