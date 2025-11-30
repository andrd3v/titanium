<table>
  <tr>
    <td>
      <img src="lol.png" alt="Titanium icon" width="64" height="64">
    </td>
    <td valign="middle">
      <h1>Titanium</h1>
    </td>
  </tr>
</table>

In‑app dylib injection with CoreTrust bypass and opainject.<br>
Titanium lets you pick a target process, optionally choose a custom `.dylib`, re‑sign it with a CoreTrust bypass, and inject it into the process on‑device.<br>
Expected to work on iOS versions supported by TrollStore (roughly iOS 14.0 – 17.0) when running with appropriate platform entitlements.<br>

---

## Build
- Uses Theos.
- Clone the repo and run:
```sh
make package
```
- Resulting Titanium.tipa will be placed in packages/.<br>
PRs and improvements are welcome.

---

## Credits

- CoreTrust bypass and signing flow based on fastPathSign.
- ROP‑based injection built around opainject.
- Various ideas inspired by the iOS jailbreak / TrollStore community.

Upstream components retain their original licenses.

## License
See [LICENSE](LICENSE).
