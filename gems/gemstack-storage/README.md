# gemstack-storage

**Merged into [`gemstack`](https://rubygems.org/gems/gemstack) in GemStack 0.3.0.**

This version is a transition shim: it depends on `gemstack` and loads `gemstack/storage`, so Gemfiles that
still list `gemstack-storage` keep working. To finish upgrading, remove `gem "gemstack-storage"` from your Gemfile
and make sure `config/app.rb` has `require "gemstack/storage"` (apps created with 0.3.0 do).

GemStack is a modular Ruby API framework for Next.js applications by
[Adware Technologies](https://www.adwaretech.com) — [gemstack-rb/gemstack](https://github.com/gemstack-rb/gemstack).

## License

Open source under the MIT License — © [Adware Technologies](https://www.adwaretech.com). See [LICENSE.txt](LICENSE.txt).
