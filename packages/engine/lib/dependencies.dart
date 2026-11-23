part of 'engine.dart';

/// A Windows runtime that Bodega installs from its vendor's own files (D2).
/// [name] is a product name, shown as it is.
typedef Dependency = ({
  String id,
  String name,

  /// Lowercase names of the DLLs that point to it in a program (D5); one `*`
  /// may stand for any run of characters.
  List<String> imports,

  /// Set to `native,builtin` for the whole bottle once it is installed (D6).
  List<String> dlls,

  /// The Windows version its installers must see, as `AppDefaults`, or null.
  String? windows,

  /// Its install for each architecture: `x86` and `x64`, or `all` for one
  /// that fills both `system32` and `syswow64` (design §2).
  Map<String, DependencyFile> files,
});

/// One file to download: [file] is its name in `downloads/`.
typedef Download = ({String url, String sha256, int bytes, String file});

/// How an install puts a runtime in the bottle (design §4).
enum DependencyKind {
  /// Runs each download headless with `args`.
  run,

  /// Takes files out of each download's cabinet (and its inner cabinets) with
  /// Wine's own `extrac32`, and copies them into the bottle.
  cab,

  /// Writes the one download at the marker.
  copy,
}

/// One install of a [Dependency]. [marker] is under `drive_c`, with at most
/// one `*` in one folder name, and shows the runtime is installed when the
/// vendor's file is there (D3). [wineManifests] are Wine's own manifests in
/// `winsxs/manifests` of the assemblies the installer brings at the same
/// version: Wine's side-by-side installer skips an assembly whose manifest
/// exists (`dlls/sxs/cache.c`, `install_assembly`), so they move aside during
/// the run (D6).
final class DependencyFile {
  const DependencyFile.run(
    this.downloads, {
    required this.marker,
    this.args = const [],
    this.wineManifests = const [],
    this.windowsDuring,
    this.replacesMono = false,
    this.netRelease,
    this.minutes = 10,
  }) : kind = DependencyKind.run,
       cabs = const [],
       take = const [],
       into = '',
       register = const [],
       fonts = const {};

  const DependencyFile.cab(
    this.downloads, {
    required this.take,
    required this.into,
    required this.marker,
    this.cabs = const [],
    this.register = const [],
    this.fonts = const {},
    this.minutes = 10,
  }) : kind = DependencyKind.cab,
       args = const [],
       wineManifests = const [],
       windowsDuring = null,
       replacesMono = false,
       netRelease = null;

  const DependencyFile.copy(this.downloads, {required this.marker})
    : kind = DependencyKind.copy,
      args = const [],
      wineManifests = const [],
      windowsDuring = null,
      replacesMono = false,
      netRelease = null,
      cabs = const [],
      take = const [],
      into = '',
      register = const [],
      fonts = const {},
      minutes = 10;

  final DependencyKind kind;
  final List<Download> downloads;
  final String marker;

  /// run: each download's silent arguments.
  final List<String> args;
  final List<String> wineManifests;

  /// run: the bottle's Windows version during the run (`winecfg -v`), set
  /// back to the bottle's own afterwards. An installer that reads the build
  /// number from the registry ignores `AppDefaults`.
  final String? windowsDuring;

  /// run: Wine Mono and Wine's `mscoree.dll` leave the bottle first (S3).
  final bool replacesMono;

  /// The least `Release` under .NET 4's `NDP\v4\Full` in `system.reg` that
  /// the marker also needs (S3).
  final int? netRelease;

  /// cab: patterns of the inner cabinets to open; empty when the files are
  /// in the download's own cabinet.
  final List<String> cabs;

  /// cab: patterns of the files to copy, into [into] in lowercase.
  final List<String> take;

  /// cab: the folder under `drive_c` they go to.
  final String into;

  /// cab: patterns of the copied DLLs that the arch's `regsvr32` registers.
  final List<String> register;

  /// cab: face names of the copied fonts by file name, registered in both
  /// `Fonts` keys as winetricks' `w_register_font` does (S1).
  final Map<String, String> fonts;

  /// The time limit for the whole install.
  final int minutes;

  /// What its downloads weigh together.
  int get bytes => downloads.fold(0, (sum, d) => sum + d.bytes);
}

/// Microsoft's own DirectX redistributable of June 2010, which holds D3DX and
/// XACT. Microsoft re-signed it, so it is not the file winetricks pins from
/// its mirror (`8746ee1a…`); checked on 2026-11-18.
const Download _directx = (
  url: 'https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/directx_Jun2010_redist.exe',
  sha256: '053f76dcbb28802e23341b6a787e3b0791c0fa5c8d4d011b1044172dbf89c73b',
  bytes: 100275120,
  file: 'directx-jun2010.exe',
);

/// Microsoft serves `d3dcompiler_47.dll` only inside the Windows SDK: this
/// is Mozilla's copy, which winetricks uses, at the commit that last changed
/// it.
const _fxc2 =
    'https://raw.githubusercontent.com/mozilla/fxc2/9aba9b11079303d5577e0e3eb455f4d00f3b5946/dll';

/// Microsoft stopped serving the core fonts in 2002: these are its original
/// packages, which winetricks uses, at the repository's last commit.
const _corefontsRepo =
    'https://raw.githubusercontent.com/pushcx/corefonts/8f8627b0004b5f1b952c09cf6390e4ae46475e59';

const List<Download> _corefontsDownloads = [
  (
    url: '$_corefontsRepo/andale32.exe',
    sha256: '0524fe42951adc3a7eb870e32f0920313c71f170c859b5f770d82b4ee111e970',
    bytes: 198384,
    file: 'corefonts-andale32.exe',
  ),
  (
    url: '$_corefontsRepo/arial32.exe',
    sha256: '85297a4d146e9c87ac6f74822734bdee5f4b2a722d7eaa584b7f2cbf76f478f6',
    bytes: 554208,
    file: 'corefonts-arial32.exe',
  ),
  (
    url: '$_corefontsRepo/arialb32.exe',
    sha256: 'a425f0ffb6a1a5ede5b979ed6177f4f4f4fdef6ae7c302a7b7720ef332fec0a8',
    bytes: 168176,
    file: 'corefonts-arialb32.exe',
  ),
  (
    url: '$_corefontsRepo/comic32.exe',
    sha256: '9c6df3feefde26d4e41d4a4fe5db2a89f9123a772594d7f59afd062625cd204e',
    bytes: 246008,
    file: 'corefonts-comic32.exe',
  ),
  (
    url: '$_corefontsRepo/courie32.exe',
    sha256: 'bb511d861655dde879ae552eb86b134d6fae67cb58502e6ff73ec5d9151f3384',
    bytes: 646368,
    file: 'corefonts-courie32.exe',
  ),
  (
    url: '$_corefontsRepo/georgi32.exe',
    sha256: '2c2c7dcda6606ea5cf08918fb7cd3f3359e9e84338dc690013f20cd42e930301',
    bytes: 392440,
    file: 'corefonts-georgi32.exe',
  ),
  (
    url: '$_corefontsRepo/impact32.exe',
    sha256: '6061ef3b7401d9642f5dfdb5f2b376aa14663f6275e60a51207ad4facf2fccfb',
    bytes: 173288,
    file: 'corefonts-impact32.exe',
  ),
  (
    url: '$_corefontsRepo/times32.exe',
    sha256: 'db56595ec6ef5d3de5c24994f001f03b2a13e37cee27bc25c58f6f43e8f807ab',
    bytes: 661728,
    file: 'corefonts-times32.exe',
  ),
  (
    url: '$_corefontsRepo/trebuc32.exe',
    sha256: '5a690d9bb8510be1b8b4fe49f1f2319651fe51bbe54775ddddd8ef0bd07fdac9',
    bytes: 357200,
    file: 'corefonts-trebuc32.exe',
  ),
  (
    url: '$_corefontsRepo/verdan32.exe',
    sha256: 'c1cb61255e363166794e47664e2f21af8e3a26cb6346eb8d2ae2fa85dd5aad96',
    bytes: 351992,
    file: 'corefonts-verdan32.exe',
  ),
  (
    url: '$_corefontsRepo/webdin32.exe',
    sha256: '64595b5abc1080fba8610c5c34fab5863408e806aafe84653ca8575bed17d75a',
    bytes: 185072,
    file: 'corefonts-webdin32.exe',
  ),
];

/// Each core font file and its face, as winetricks registers them.
const _fontFaces = {
  'andalemo.ttf': 'Andale Mono',
  'arial.ttf': 'Arial',
  'arialbd.ttf': 'Arial Bold',
  'arialbi.ttf': 'Arial Bold Italic',
  'ariali.ttf': 'Arial Italic',
  'ariblk.ttf': 'Arial Black',
  'comic.ttf': 'Comic Sans MS',
  'comicbd.ttf': 'Comic Sans MS Bold',
  'cour.ttf': 'Courier New',
  'courbd.ttf': 'Courier New Bold',
  'courbi.ttf': 'Courier New Bold Italic',
  'couri.ttf': 'Courier New Italic',
  'georgia.ttf': 'Georgia',
  'georgiab.ttf': 'Georgia Bold',
  'georgiai.ttf': 'Georgia Italic',
  'georgiaz.ttf': 'Georgia Bold Italic',
  'impact.ttf': 'Impact',
  'times.ttf': 'Times New Roman',
  'timesbd.ttf': 'Times New Roman Bold',
  'timesbi.ttf': 'Times New Roman Bold Italic',
  'timesi.ttf': 'Times New Roman Italic',
  'trebuc.ttf': 'Trebuchet MS',
  'trebucbd.ttf': 'Trebuchet MS Bold',
  'trebucbi.ttf': 'Trebuchet MS Bold Italic',
  'trebucit.ttf': 'Trebuchet MS Italic',
  'verdana.ttf': 'Verdana',
  'verdanab.ttf': 'Verdana Bold',
  'verdanai.ttf': 'Verdana Italic',
  'verdanaz.ttf': 'Verdana Bold Italic',
  'webdings.ttf': 'Webdings',
};

const _xactFiles = [
  'xactengine*.dll',
  'xaudio*.dll',
  'x3daudio*.dll',
  'xapofx*.dll',
];
const _xactRegister = [
  'xactengine*.dll',
  'xaudio2_0.dll',
  'xaudio2_1.dll',
  'xaudio2_2.dll',
  'xaudio2_3.dll',
  'xaudio2_4.dll',
  'xaudio2_5.dll',
  'xaudio2_6.dll',
  'xaudio2_7.dll',
];

/// The runtimes Bodega installs (D2), never stored in Bodega. Facts, not code,
/// read from winetricks (LGPL-2.1-or-later) by verb at `20260125`
/// (`load_vcrun2005`…`load_vcrun2013`, `load_dotnet40`, `load_dotnet48`,
/// `load_d3dx9`, `load_d3dx10`, `load_d3dx11_43`, `load_d3dcompiler_47`,
/// `load_xact`, `load_xact_x64`, `load_physx`, `load_corefonts`), and
/// highball-db's `recipes/tweaks/vcrun2022.json` at 7a008d5 (CC0) for the
/// 2015–2026 pins and their need of Windows 10. Every size and SHA-256 was
/// checked against a real download: Visual C++ on 2026-11-16, the rest on
/// 2026-11-18. Each URL is the vendor's own server, except `_fxc2` and
/// `_corefontsRepo`, which no vendor serves any more.
const dependencies = <Dependency>[
  (
    id: 'vcrun2005',
    name: 'Visual C++ 2005',
    imports: ['msvcr80.dll', 'msvcp80.dll', 'mfc80.dll', 'mfc80u.dll'],
    dlls: ['atl80', 'msvcm80', 'msvcp80', 'msvcr80', 'vcomp'],
    windows: null,
    files: {
      'x86': DependencyFile.run(
        [
          (
            url: 'https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x86.EXE',
            sha256: '8648c5fc29c44b9112fe52f9a33f80e7fc42d10f3b5b42b2121542a13e44adfd',
            bytes: 2710520,
            file: 'vcrun2005-x86.exe',
          ),
        ],
        args: ['/q'],
        marker: 'windows/winsxs/x86_microsoft.vc80.crt_1fc8b3b9a1e18e3b_8.0.50727.6195_*/msvcr80.dll',
      ),
      'x64': DependencyFile.run(
        [
          (
            url: 'https://download.microsoft.com/download/8/B/4/8B42259F-5D70-43F4-AC2E-4B208FD8D66A/vcredist_x64.EXE',
            sha256: '4487570bd86e2e1aac29db2a1d0a91eb63361fcaac570808eb327cd4e0e2240d',
            bytes: 3179000,
            file: 'vcrun2005-x64.exe',
          ),
        ],
        args: ['/q'],
        marker: 'windows/winsxs/amd64_microsoft.vc80.crt_1fc8b3b9a1e18e3b_8.0.50727.6195_*/msvcr80.dll',
      ),
    },
  ),
  (
    id: 'vcrun2008',
    name: 'Visual C++ 2008',
    imports: ['msvcr90.dll', 'msvcp90.dll', 'mfc90.dll', 'mfc90u.dll'],
    dlls: ['atl90', 'msvcm90', 'msvcp90', 'msvcr90', 'vcomp90'],
    windows: null,
    files: {
      'x86': DependencyFile.run(
        [
          (
            url: 'https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x86.exe',
            sha256: '8742bcbf24ef328a72d2a27b693cc7071e38d3bb4b9b44dec42aa3d2c8d61d92',
            bytes: 4483040,
            file: 'vcrun2008-x86.exe',
          ),
        ],
        args: ['/q'],
        marker: 'windows/winsxs/x86_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_*/msvcr90.dll',
        wineManifests: [
          'x86_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_*.manifest',
          'x86_microsoft.vc90.atl_1fc8b3b9a1e18e3b_9.0.30729.6161_*.manifest',
        ],
      ),
      'x64': DependencyFile.run(
        [
          (
            url: 'https://download.microsoft.com/download/5/D/8/5D8C65CB-C849-4025-8E95-C3966CAFD8AE/vcredist_x64.exe',
            sha256: 'c5e273a4a16ab4d5471e91c7477719a2f45ddadb76c7f98a38fa5074a6838654',
            bytes: 5211080,
            file: 'vcrun2008-x64.exe',
          ),
        ],
        args: ['/q'],
        marker: 'windows/winsxs/amd64_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_*/msvcr90.dll',
        wineManifests: [
          'amd64_microsoft.vc90.crt_1fc8b3b9a1e18e3b_9.0.30729.6161_*.manifest',
          'amd64_microsoft.vc90.atl_1fc8b3b9a1e18e3b_9.0.30729.6161_*.manifest',
        ],
      ),
    },
  ),
  (
    id: 'vcrun2010',
    name: 'Visual C++ 2010',
    imports: ['msvcr100.dll', 'msvcp100.dll', 'mfc100.dll', 'mfc100u.dll'],
    dlls: ['atl100', 'msvcp100', 'msvcr100', 'vcomp100'],
    windows: null,
    files: {
      'x86': DependencyFile.run(
        [
          (
            url: 'https://download.microsoft.com/download/5/B/C/5BC5DBB3-652D-4DCE-B14A-475AB85EEF6E/vcredist_x86.exe',
            sha256: '31d32fa39d52cac9a765a43660431f7a127eee784b54b2f5e2af3e2b763a1af8',
            bytes: 5076456,
            file: 'vcrun2010-x86.exe',
          ),
        ],
        args: ['/q'],
        marker: 'windows/syswow64/msvcr100.dll',
      ),
      'x64': DependencyFile.run(
        [
          (
            url: 'https://download.microsoft.com/download/A/8/0/A80747C3-41BD-45DF-B505-E9710D2744E0/vcredist_x64.exe',
            sha256: '2fddbc3aaaab784c16bc673c3bae5f80929d5b372810dbc28649283566d33255',
            bytes: 5677032,
            file: 'vcrun2010-x64.exe',
          ),
        ],
        args: ['/q'],
        marker: 'windows/system32/msvcr100.dll',
      ),
    },
  ),
  (
    id: 'vcrun2012',
    name: 'Visual C++ 2012',
    imports: ['msvcr110.dll', 'msvcp110.dll', 'mfc110.dll', 'mfc110u.dll'],
    dlls: ['atl110', 'msvcp110', 'msvcr110', 'vcomp110'],
    windows: null,
    files: {
      'x86': DependencyFile.run(
        [
          (
            url: 'https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x86.exe',
            sha256: 'b924ad8062eaf4e70437c8be50fa612162795ff0839479546ce907ffa8d6e386',
            bytes: 6554576,
            file: 'vcrun2012-x86.exe',
          ),
        ],
        args: ['/q'],
        marker: 'windows/syswow64/msvcr110.dll',
      ),
      'x64': DependencyFile.run(
        [
          (
            url: 'https://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe',
            sha256: '681be3e5ba9fd3da02c09d7e565adfa078640ed66a0d58583efad2c1e3cc4064',
            bytes: 7186992,
            file: 'vcrun2012-x64.exe',
          ),
        ],
        args: ['/q'],
        marker: 'windows/system32/msvcr110.dll',
      ),
    },
  ),
  (
    id: 'vcrun2013',
    name: 'Visual C++ 2013',
    imports: ['msvcr120.dll', 'msvcp120.dll', 'mfc120.dll', 'mfc120u.dll'],
    dlls: ['atl120', 'msvcp120', 'msvcr120', 'vcomp120'],
    windows: null,
    files: {
      'x86': DependencyFile.run(
        [
          (
            url: 'https://download.microsoft.com/download/0/5/6/056dcda9-d667-4e27-8001-8a0c6971d6b1/vcredist_x86.exe',
            sha256: '89f4e593ea5541d1c53f983923124f9fd061a1c0c967339109e375c661573c17',
            bytes: 6510544,
            file: 'vcrun2013-x86.exe',
          ),
        ],
        args: ['/q'],
        marker: 'windows/syswow64/msvcr120.dll',
      ),
      'x64': DependencyFile.run(
        [
          (
            url: 'https://download.microsoft.com/download/0/5/6/056dcda9-d667-4e27-8001-8a0c6971d6b1/vcredist_x64.exe',
            sha256: '20e2645b7cd5873b1fa3462b99a665ac8d6e14aae83ded9d875fea35ffdd7d7e',
            bytes: 7201032,
            file: 'vcrun2013-x64.exe',
          ),
        ],
        args: ['/q'],
        marker: 'windows/system32/msvcr120.dll',
      ),
    },
  ),
  (
    id: 'vcrun2022',
    name: 'Visual C++ 2015–2026',
    imports: [
      'vcruntime140.dll',
      'vcruntime140_1.dll',
      'msvcp140.dll',
      'msvcp140_1.dll',
      'msvcp140_2.dll',
      'concrt140.dll',
      'mfc140.dll',
      'mfc140u.dll',
    ],
    dlls: [
      'concrt140',
      'msvcp140',
      'msvcp140_1',
      'msvcp140_2',
      'msvcp140_atomic_wait',
      'msvcp140_codecvt_ids',
      'vcamp140',
      'vccorlib140',
      'vcomp140',
      'vcruntime140',
      'vcruntime140_1',
    ],
    // Its installers exit 1 when they see Windows 7 (highball-db's recipe).
    windows: 'win10',
    files: {
      'x86': DependencyFile.run(
        [
          (
            url: 'https://download.visualstudio.microsoft.com/download/pr/6ad63323-a427-4c58-8464-9f1f19f62359/F0BAB33A302B3CDB2E11113760D016F54FD3D2632C65BA7834FAC4F0ABD7F1A3/VC_redist.x86.exe',
            sha256: 'f0bab33a302b3cdb2e11113760d016f54fd3d2632c65ba7834fac4f0abd7f1a3',
            bytes: 6941536,
            file: 'vcrun2022-x86.exe',
          ),
        ],
        args: ['/install', '/quiet', '/norestart'],
        marker: 'windows/syswow64/vcruntime140.dll',
      ),
      'x64': DependencyFile.run(
        [
          (
            url: 'https://download.visualstudio.microsoft.com/download/pr/ebdab8e5-1d7b-4d9f-a11b-cbb1720c3b12/843068991DAAA1F73AD9F6239BCE4D0F6A07A51F18C37EA2A867E9BECA71295C/VC_redist.x64.exe',
            sha256: '843068991daaa1f73ad9f6239bce4d0f6a07a51f18c37ea2a867e9beca71295c',
            bytes: 18731856,
            file: 'vcrun2022-x64.exe',
          ),
        ],
        args: ['/install', '/quiet', '/norestart'],
        marker: 'windows/system32/vcruntime140.dll',
      ),
    },
  ),
  (
    id: 'dotnet48',
    name: '.NET Framework 4.8',
    imports: ['mscoree.dll'],
    dlls: ['mscoree'],
    windows: null,
    files: {
      // S3, measured on 2026-11-18: 4.8 alone stops at "already installed"
      // while Wine Mono is there or the bottle says Windows 10, and only 4.0
      // brings Microsoft's mscoree.dll. Under Rosetta the two took 58 min,
      // and .NET compiling its native images about 15 more.
      'all': DependencyFile.run(
        [
          (
            url: 'https://download.microsoft.com/download/9/5/A/95A9616B-7A37-4AF6-BC36-D6EA96C8DAAE/dotNetFx40_Full_x86_x64.exe',
            sha256: '65e064258f2e418816b304f646ff9e87af101e4c9552ab064bb74d281c38659f',
            bytes: 50449456,
            file: 'dotnet40.exe',
          ),
          (
            url: 'https://download.visualstudio.microsoft.com/download/pr/7afca223-55d2-470a-8edc-6a1739ae3252/abd170b4b0ec15ad0222a809b761a036/ndp48-x86-x64-allos-enu.exe',
            sha256: '95889d6de3f2070c07790ad6cf2000d33d9a1bdfc6a381725ab82ab1c314fd53',
            bytes: 72721568,
            file: 'dotnet48.exe',
          ),
        ],
        args: ['/q', '/norestart'],
        marker: 'windows/Microsoft.NET/Framework/v4.0.30319/clr.dll',
        netRelease: 528040,
        replacesMono: true,
        windowsDuring: 'win7',
        minutes: 120,
      ),
    },
  ),
  (
    id: 'd3dx9',
    name: 'D3DX9',
    imports: ['d3dx9_*.dll'],
    dlls: [
      'd3dx9_24',
      'd3dx9_25',
      'd3dx9_26',
      'd3dx9_27',
      'd3dx9_28',
      'd3dx9_29',
      'd3dx9_30',
      'd3dx9_31',
      'd3dx9_32',
      'd3dx9_33',
      'd3dx9_34',
      'd3dx9_35',
      'd3dx9_36',
      'd3dx9_37',
      'd3dx9_38',
      'd3dx9_39',
      'd3dx9_40',
      'd3dx9_41',
      'd3dx9_42',
      'd3dx9_43',
    ],
    windows: null,
    files: {
      'x86': DependencyFile.cab(
        [_directx],
        cabs: ['*d3dx9*x86*.cab'],
        take: ['d3dx9*.dll'],
        into: 'windows/syswow64',
        marker: 'windows/syswow64/d3dx9_43.dll',
      ),
      'x64': DependencyFile.cab(
        [_directx],
        cabs: ['*d3dx9*x64*.cab'],
        take: ['d3dx9*.dll'],
        into: 'windows/system32',
        marker: 'windows/system32/d3dx9_43.dll',
      ),
    },
  ),
  (
    id: 'd3dx10',
    name: 'D3DX10',
    imports: ['d3dx10_*.dll', 'd3dx10.dll'],
    dlls: [
      'd3dx10',
      'd3dx10_33',
      'd3dx10_34',
      'd3dx10_35',
      'd3dx10_36',
      'd3dx10_37',
      'd3dx10_38',
      'd3dx10_39',
      'd3dx10_40',
      'd3dx10_41',
      'd3dx10_42',
      'd3dx10_43',
    ],
    windows: null,
    files: {
      'x86': DependencyFile.cab(
        [_directx],
        cabs: ['*d3dx10*x86*.cab'],
        take: ['d3dx10*.dll'],
        into: 'windows/syswow64',
        marker: 'windows/syswow64/d3dx10_43.dll',
      ),
      'x64': DependencyFile.cab(
        [_directx],
        cabs: ['*d3dx10*x64*.cab'],
        take: ['d3dx10*.dll'],
        into: 'windows/system32',
        marker: 'windows/system32/d3dx10_43.dll',
      ),
    },
  ),
  (
    id: 'd3dx11_43',
    name: 'D3DX11',
    imports: ['d3dx11_43.dll'],
    dlls: ['d3dx11_43'],
    windows: null,
    files: {
      'x86': DependencyFile.cab(
        [_directx],
        cabs: ['*d3dx11_43*x86*.cab'],
        take: ['d3dx11_43.dll'],
        into: 'windows/syswow64',
        marker: 'windows/syswow64/d3dx11_43.dll',
      ),
      'x64': DependencyFile.cab(
        [_directx],
        cabs: ['*d3dx11_43*x64*.cab'],
        take: ['d3dx11_43.dll'],
        into: 'windows/system32',
        marker: 'windows/system32/d3dx11_43.dll',
      ),
    },
  ),
  (
    id: 'd3dcompiler_47',
    name: 'D3DCompiler 47',
    imports: ['d3dcompiler_47.dll'],
    dlls: ['d3dcompiler_47'],
    windows: null,
    files: {
      'x86': DependencyFile.copy([
        (
          url: '$_fxc2/d3dcompiler_47_32.dll',
          sha256: '2ad0d4987fc4624566b190e747c9d95038443956ed816abfd1e2d389b5ec0851',
          bytes: 3657992,
          file: 'd3dcompiler_47-x86.dll',
        ),
      ], marker: 'windows/syswow64/d3dcompiler_47.dll'),
      'x64': DependencyFile.copy([
        (
          url: '$_fxc2/d3dcompiler_47.dll',
          sha256: '4432bbd1a390874f3f0a503d45cc48d346abc3a8c0213c289f4b615bf0ee84f3',
          bytes: 4346120,
          file: 'd3dcompiler_47-x64.dll',
        ),
      ], marker: 'windows/system32/d3dcompiler_47.dll'),
    },
  ),
  (
    id: 'xact',
    name: 'XACT',
    imports: ['x3daudio1_*.dll', 'xapofx1_*.dll'],
    dlls: [
      'xaudio2_0',
      'xaudio2_1',
      'xaudio2_2',
      'xaudio2_3',
      'xaudio2_4',
      'xaudio2_5',
      'xaudio2_6',
      'xaudio2_7',
      'x3daudio1_0',
      'x3daudio1_1',
      'x3daudio1_2',
      'x3daudio1_3',
      'x3daudio1_4',
      'x3daudio1_5',
      'x3daudio1_6',
      'x3daudio1_7',
      'xapofx1_1',
      'xapofx1_2',
      'xapofx1_3',
      'xapofx1_4',
      'xapofx1_5',
      'xactengine2_0',
      'xactengine2_1',
      'xactengine2_2',
      'xactengine2_3',
      'xactengine2_4',
      'xactengine2_5',
      'xactengine2_6',
      'xactengine2_7',
      'xactengine2_8',
      'xactengine2_9',
      'xactengine2_10',
      'xactengine3_0',
      'xactengine3_1',
      'xactengine3_2',
      'xactengine3_3',
      'xactengine3_4',
      'xactengine3_5',
      'xactengine3_6',
      'xactengine3_7',
    ],
    windows: null,
    files: {
      'x86': DependencyFile.cab(
        [_directx],
        cabs: [
          '*_xact_*x86*.cab',
          '*_x3daudio_*x86*.cab',
          '*_xaudio_*x86*.cab',
        ],
        take: _xactFiles,
        into: 'windows/syswow64',
        register: _xactRegister,
        marker: 'windows/syswow64/xactengine3_7.dll',
      ),
      'x64': DependencyFile.cab(
        [_directx],
        cabs: [
          '*_xact_*x64*.cab',
          '*_x3daudio_*x64*.cab',
          '*_xaudio_*x64*.cab',
        ],
        take: _xactFiles,
        into: 'windows/system32',
        register: _xactRegister,
        marker: 'windows/system32/xactengine3_7.dll',
      ),
    },
  ),
  (
    id: 'physx',
    name: 'PhysX',
    imports: ['physxloader.dll'],
    dlls: [],
    windows: null,
    files: {
      // S4: the installer adds this folder to the system PATH, where games
      // find the loader.
      'all': DependencyFile.run(
        [
          (
            url: 'https://us.download.nvidia.com/Windows/9.23.1019/PhysX_9.23.1019_SystemSoftware.exe',
            sha256: '9b42b84e881769d681e09f62a1b51532616b2e6a2d5d99d0ccae6eb5fbbc208c',
            bytes: 29417888,
            file: 'physx.exe',
          ),
        ],
        args: ['/s'],
        marker: 'Program Files (x86)/NVIDIA Corporation/PhysX/Common/PhysXLoader.dll',
      ),
    },
  ),
  (
    id: 'corefonts',
    name: 'Core fonts for the Web',
    imports: [],
    dlls: [],
    windows: null,
    files: {
      'all': DependencyFile.cab(
        _corefontsDownloads,
        take: ['*.ttf'],
        into: 'windows/Fonts',
        fonts: _fontFaces,
        marker: 'windows/Fonts/arial.ttf',
      ),
    },
  ),
];

/// Where the runtimes come from. A test replaces it; the app never does.
List<Dependency> dependencyTable = dependencies;

/// The row [id] of [dependencyTable], and its install for [arch].
(Dependency, DependencyFile) _dependencyFile(String id, String arch) {
  final row = dependencyTable.where((row) => row.id == id).firstOrNull;
  final file = row?.files[arch];
  if (row == null || file == null) {
    throw BadChoice(ChoiceKind.dependency, '$id $arch');
  }
  return (row, file);
}

/// Whether runtime [id] for [arch] is in the bottle (D3), read from the bottle
/// itself, so that one a game's own installer added counts too: true, false,
/// or null when the bottle's files can't be read (design §5).
///
/// A `.dll` or `.exe` marker is a regular file, reached without a link, that
/// starts as a PE does and carries none of the marks Wine writes in its own
/// DLLs; a .NET marker also needs its `Release` (S3). A font marker is a
/// regular file, or a font of the same name that Wine lists from the host:
/// on the Mac, macOS's own core fonts (S1).
bool? dependencyStatus(String home, String bottle, String id, String arch) {
  final (_, file) = _dependencyFile(id, arch);
  final prefix = '${_existing(home, bottle)}/prefix';
  try {
    final found = _markerFiles('$prefix/drive_c', file.marker);
    final name = file.marker.split('/').last.toLowerCase();
    if (!name.endsWith('.dll') && !name.endsWith('.exe')) {
      return found.isNotEmpty || _externalFonts(prefix).contains(name);
    }
    final release = file.netRelease;
    return found.any(_isVendors) &&
        (release == null || (_netRelease(prefix) ?? 0) >= release);
  } on FileSystemException {
    return null;
  }
}

/// Whether runtime [id] for [arch] is surely in the bottle.
bool dependencyInstalled(String home, String bottle, String id, String arch) =>
    dependencyStatus(home, bottle, id, arch) == true;

/// Where a UI puts the files of [id] for [arch] before handing them to
/// [installDependency], in order (`downloads/<file>`, the cache `_download`
/// uses too), and what each must be.
List<({String url, String sha256, int bytes, String path})> dependencyDownload(
  String home,
  String id,
  String arch,
) {
  final (_, file) = _dependencyFile(id, arch);
  return [
    for (final d in file.downloads)
      (
        url: d.url,
        sha256: d.sha256,
        bytes: d.bytes,
        path: '$home/downloads/${d.file}',
      ),
  ];
}

/// Every runtime and arch of the table, with its status.
List<({String id, String arch, bool? installed})> bottleDependencies(
  String home,
  String bottle,
) => [
  for (final row in dependencyTable)
    for (final arch in row.files.keys)
      (
        id: row.id,
        arch: arch,
        installed: dependencyStatus(home, bottle, row.id, arch),
      ),
];

/// The files under [drive] that [marker] names: each part matched without case
/// among the real entries of the folder before it, a `*` standing for any run
/// of characters. No link is followed: `dosdevices/z:` is `/`.
List<String> _markerFiles(String drive, String marker) {
  final parts = marker.split('/');
  var found = [drive];
  for (final (i, part) in parts.indexed) {
    final last = i == parts.length - 1;
    found = [
      for (final dir in found)
        if (_isRealDirectory(dir))
          for (final entry in Directory(dir).listSync(followLinks: false))
            if (_nameMatches(entry.path.split('/').last, part) &&
                FileSystemEntity.typeSync(entry.path, followLinks: false) ==
                    (last
                        ? FileSystemEntityType.file
                        : FileSystemEntityType.directory))
              entry.path,
    ];
  }
  return found;
}

/// [name] against [pattern], without case; each `*` stands for any run of
/// characters.
bool _nameMatches(String name, String pattern) => RegExp(
  '^${pattern.split('*').map(RegExp.escape).join('.*')}\$',
  caseSensitive: false,
).hasMatch(name);

/// Whether [path] starts as a PE does and lacks Wine's marks in its first 128
/// bytes, where Wine writes them in its own DLLs: a vendor's DLL.
bool _isVendors(String path) {
  final file = File(path).openSync();
  try {
    final head = file.readSync(128);
    if (head.length < 64 || head[0] != 0x4D || head[1] != 0x5A) return false;
    final text = latin1.decode(head);
    return !text.contains('Wine builtin DLL') &&
        !text.contains('Wine placeholder DLL');
  } finally {
    file.closeSync();
  }
}

/// The values of [key] in Wine's registry file [path], as written there
/// (`"text"`, `dword:…`), by name; empty when there is no file or no key.
/// [key] is written as the file writes it, with `\\` between its parts.
Map<String, String> _regValues(String path, String key) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  final header = '[${key.toLowerCase()}]';
  final values = <String, String>{};
  var inside = false;
  for (final line in file.readAsLinesSync(encoding: latin1)) {
    if (line.startsWith('[')) {
      if (inside) break;
      inside = line.toLowerCase().startsWith(header);
    } else if (inside) {
      final value = RegExp(r'^"((?:[^"\\]|\\.)*)"=(.*)$').firstMatch(line);
      if (value != null) values[value[1]!] = value[2]!;
    }
  }
  return values;
}

/// The lowercase file names of the fonts Wine lists from the host in the
/// prefix's `user.reg` (S1).
Set<String> _externalFonts(String prefix) => {
  for (final value in _regValues(
    '$prefix/user.reg',
    r'Software\\Wine\\Fonts\\External Fonts',
  ).values)
    value.replaceAll('"', '').split(r'\').last.toLowerCase(),
};

/// .NET 4's `Release` in the prefix's `system.reg`, or null (S3).
int? _netRelease(String prefix) {
  final value = _regValues(
    '$prefix/system.reg',
    r'Software\\Microsoft\\NET Framework Setup\\NDP\\v4\\Full',
  )['Release'];
  return value != null && value.startsWith('dword:')
      ? int.tryParse(value.substring(6), radix: 16)
      : null;
}

/// What a program shows of its needs (D4): its bits, the DLLs it imports or
/// delay-loads, the side-by-side assemblies its manifest names, and the DLLs
/// that sit beside it. Names are lowercase.
typedef ProgramScan = ({
  int bits,
  Set<String> imports,
  Set<String> assemblies,
  Set<String> besideIt,
});

/// D4: reads [path]'s headers, import tables and manifest, never the whole
/// file, in another isolate. Null if it is not a PE on x86. A table that leads
/// outside the file ends the reading there: what was read stands.
Future<ProgramScan?> scanProgram(String path) =>
    Isolate.run(() => _scanProgram(path));

ProgramScan? _scanProgram(String path) {
  if (FileSystemEntity.typeSync(path) != FileSystemEntityType.file) return null;
  final bits = _peBits(path);
  if (bits == null) return null;
  final file = File(path).openSync();
  final ({Set<String> imports, Set<String> assemblies}) found;
  try {
    found = _Pe(file, bits).read();
  } finally {
    file.closeSync();
  }
  // ponytail: only the DLLs' names; the DLLs beside an exe import runtimes
  // too, and reading them is the upgrade path.
  final folder = File(path).parent;
  return (
    bits: bits,
    imports: found.imports,
    assemblies: found.assemblies,
    besideIt: {
      for (final entry in folder.listSync(followLinks: false))
        if (entry.path.toLowerCase().endsWith('.dll') &&
            FileSystemEntity.typeSync(entry.path, followLinks: false) ==
                FileSystemEntityType.file)
          entry.path.split('/').last.toLowerCase(),
    },
  );
}

/// Reads one PE by positions: headers, the import and delay-import tables,
/// and the manifest resource.
class _Pe {
  _Pe(this.file, this.bits);

  final RandomAccessFile file;
  final int bits;
  late final int _length = file.lengthSync();
  final _sections = <({int va, int size, int raw})>[];
  int _imageBase = 0;
  List<({int rva, int size})> _directories = const [];

  /// [count] bytes at [offset], or null when the file ends before them.
  ByteData? _at(int offset, int count) {
    if (offset < 0 || count < 0 || offset + count > _length) return null;
    file.setPositionSync(offset);
    final bytes = file.readSync(count);
    return bytes.length == count ? ByteData.sublistView(bytes) : null;
  }

  int? _offset(int rva) {
    for (final s in _sections) {
      if (rva >= s.va && rva < s.va + s.size) {
        final offset = s.raw + rva - s.va;
        return offset < _length ? offset : null;
      }
    }
    return null;
  }

  /// The zero-ended text at [rva], at most 256 bytes.
  String? _name(int rva) {
    final offset = _offset(rva);
    if (offset == null) return null;
    file.setPositionSync(offset);
    final bytes = file.readSync(256);
    final end = bytes.indexOf(0);
    if (end <= 0) return null;
    return latin1.decode(bytes.sublist(0, end)).toLowerCase();
  }

  ({Set<String> imports, Set<String> assemblies}) read() {
    final imports = <String>{}, assemblies = <String>{};
    if (!_headers()) return (imports: imports, assemblies: assemblies);
    _table(1, 20, 12, imports, delay: false);
    _table(13, 32, 4, imports, delay: true);
    final manifest = _manifest();
    if (manifest != null) {
      for (final match in RegExp(
        r'''name\s*=\s*["'](microsoft\.vc[0-9]+\.(?:crt|mfc))["']''',
        caseSensitive: false,
      ).allMatches(manifest)) {
        assemblies.add(match[1]!.toLowerCase());
      }
    }
    return (imports: imports, assemblies: assemblies);
  }

  bool _headers() {
    final dos = _at(0, 64);
    if (dos == null) return false;
    final pe = dos.getUint32(60, Endian.little);
    final coff = _at(pe + 4, 20);
    if (coff == null) return false;
    final sections = coff.getUint16(2, Endian.little);
    final optionalSize = coff.getUint16(16, Endian.little);
    final optional = pe + 24;
    final header = _at(optional, optionalSize);
    if (header == null) return false;
    final wide = bits == 64;
    if (header.lengthInBytes < (wide ? 112 : 96)) return false;
    _imageBase = wide
        ? header.getUint64(24, Endian.little)
        : header.getUint32(28, Endian.little);
    final count = header.getUint32(wide ? 108 : 92, Endian.little);
    final first = wide ? 112 : 96;
    _directories = [
      for (var i = 0; i < count && first + 8 * i + 8 <= optionalSize; i++)
        (
          rva: header.getUint32(first + 8 * i, Endian.little),
          size: header.getUint32(first + 8 * i + 4, Endian.little),
        ),
    ];
    final table = _at(optional + optionalSize, 40 * sections);
    if (table == null) return false;
    for (var i = 0; i < sections; i++) {
      final virtualSize = table.getUint32(40 * i + 8, Endian.little);
      final rawSize = table.getUint32(40 * i + 16, Endian.little);
      _sections.add((
        va: table.getUint32(40 * i + 12, Endian.little),
        size: virtualSize > rawSize ? virtualSize : rawSize,
        raw: table.getUint32(40 * i + 20, Endian.little),
      ));
    }
    return true;
  }

  /// The DLL names of the table in data directory [index], whose entries are
  /// [size] bytes with the name's address at [nameAt]; it ends at an entry of
  /// zeros, or where the file does. A delay-load entry of the oldest kind
  /// (attributes 0) holds addresses rather than RVAs.
  void _table(
    int index,
    int size,
    int nameAt,
    Set<String> into, {
    required bool delay,
  }) {
    if (index >= _directories.length || _directories[index].rva == 0) return;
    var offset = _offset(_directories[index].rva);
    for (var i = 0; offset != null && i < 4096; i++, offset += size) {
      final entry = _at(offset, size);
      if (entry == null) return;
      if (Iterable<int>.generate(size, entry.getUint8).every((b) => b == 0)) {
        return;
      }
      var rva = entry.getUint32(nameAt, Endian.little);
      if (delay && entry.getUint32(0, Endian.little) & 1 == 0) {
        rva -= _imageBase;
      }
      if (_name(rva) case final name?) into.add(name);
    }
  }

  /// The text of the first RT_MANIFEST resource (type 24), at most 64 KiB.
  String? _manifest() {
    if (_directories.length < 3 || _directories[2].rva == 0) return null;
    final root = _offset(_directories[2].rva);
    if (root == null) return null;

    /// The offset of the entry with [id] (or the first, for null) in the
    /// resource directory at [dir], and whether it is a directory.
    (int, bool)? entry(int dir, int? id) {
      final head = _at(dir, 16);
      if (head == null) return null;
      final count =
          head.getUint16(12, Endian.little) + head.getUint16(14, Endian.little);
      for (var i = 0; i < count && i < 512; i++) {
        final item = _at(dir + 16 + 8 * i, 8);
        if (item == null) return null;
        final name = item.getUint32(0, Endian.little);
        if (id != null && name != id) continue;
        final to = item.getUint32(4, Endian.little);
        return (root + (to & 0x7fffffff), to & 0x80000000 != 0);
      }
      return null;
    }

    final type = entry(root, 24);
    if (type == null || !type.$2) return null;
    final name = entry(type.$1, null);
    if (name == null || !name.$2) return null;
    final language = entry(name.$1, null);
    if (language == null || language.$2) return null;
    final data = _at(language.$1, 8);
    if (data == null) return null;
    final at = _offset(data.getUint32(0, Endian.little));
    final size = data.getUint32(4, Endian.little);
    if (at == null) return null;
    final text = _at(at, size < 65536 ? size : 65536);
    return text == null
        ? null
        : latin1.decode(
            text.buffer.asUint8List(text.offsetInBytes, text.lengthInBytes),
          );
  }
}

/// How much Bodega wants a runtime for a program (D5).
enum Need { recommended, optional }

/// Why: a fix names it, Wine has no copy of a DLL the program imports, or the
/// program imports a DLL that Wine also provides.
enum NeedReason { knownFix, notInWine, imported }

/// One runtime a program needs. [dll] is the import that pointed to it, [fix]
/// the fix that named it; [installed] keeps a need that is met in the list,
/// and is null when the bottle can't be read.
typedef DependencyNeed = ({
  String id,
  String arch,
  Need need,
  NeedReason reason,
  String? dll,
  String? fix,
  bool? installed,
});

/// Where a fix's settings step stands in the game's file (D9).
enum SettingState { applied, notApplied, noFile }

/// One setting a fix changes in the game's own file.
typedef SettingNeed = ({
  String fix,
  String section,
  String name,
  String value,
  SettingState state,
});

/// What Bodega proposes for one application of a bottle (D5).
typedef AppNeeds = ({
  String key,
  List<DependencyNeed> dependencies,
  List<SettingNeed> settings,
});

/// D5: worked out each time from the bottle, the program and the fixes, never
/// stored. Recommended: a runtime a fix names, or one whose DLL the program
/// imports and the runtime's Wine lacks (MFC, PhysX's loader; design §6).
/// Optional: one whose DLL it imports and Wine also provides. An import the
/// game ships beside its exe proposes nothing. A runtime with one install for
/// both arches is proposed as `all`. Steam games open through steam.exe, so
/// nothing is read for them: their fixes' settings count, and the runtimes
/// they name for `all`. ponytail: a Steam fix that names a runtime per arch
/// would need the game's own exe (the appmanifest's `installdir`); none does
/// yet.
Future<AppNeeds> appNeeds(String home, String bottle, String key) async {
  final dir = _existing(home, bottle);
  final app =
      _appsIn(bottle, dir).where((app) => app.key == key).firstOrNull ??
      (throw AppNotFound(bottle, key));
  final fix = _gameIn(dir, app)?.fix;
  final needs = <String, DependencyNeed>{};
  void add(String id, String arch, Need need, NeedReason reason, String? dll) {
    final old = needs[id];
    if (old != null &&
        reason != NeedReason.knownFix &&
        (old.need == Need.recommended || need == Need.optional)) {
      return;
    }
    needs[id] = (
      id: id,
      arch: arch,
      need: need,
      reason: reason,
      dll: dll,
      fix: reason == NeedReason.knownFix ? fix?.id : null,
      installed: dependencyStatus(home, bottle, id, arch),
    );
  }

  /// The arch [id] installs for: `all`, or the program's; null for an id
  /// that is not in the table, or a program that was not read.
  String? archFor(String id, String? program) {
    final row = dependencyTable.where((row) => row.id == id).firstOrNull;
    if (row == null) return null;
    return row.files.containsKey('all') ? 'all' : program;
  }

  String? arch;

  if (!key.startsWith('steam:')) {
    final exe = app.exe.startsWith('/')
        ? app.exe
        : findCI('$dir/prefix/drive_c', app.exe);
    if (await scanProgram(exe) case final scan?) {
      arch = scan.bits == 64 ? 'x64' : 'x86';
      // Without a runtime nothing is known to be missing from Wine. Mach9's
      // x64 programs load its ARM64X modules (PE10).
      final rt = _installedRuntime(home, dir);
      final wine = rt == null
          ? null
          : '$rt/engine/lib/wine/'
                '${scan.bits == 64 ? (_bottleRuntimeIn(dir) == RuntimeKind.mach9 ? 'aarch64' : 'x86_64') : 'i386'}-windows';
      for (final row in dependencyTable) {
        for (final pattern in row.imports) {
          for (final dll in scan.imports) {
            if (!_nameMatches(dll, pattern) || scan.besideIt.contains(dll)) {
              continue;
            }
            final missing = wine != null && !File('$wine/$dll').existsSync();
            add(
              row.id,
              archFor(row.id, arch)!,
              missing ? Need.recommended : Need.optional,
              missing ? NeedReason.notInWine : NeedReason.imported,
              dll,
            );
          }
        }
      }
      for (final assembly in scan.assemblies) {
        final id = switch (RegExp(r'vc(\d+)').firstMatch(assembly)?[1]) {
          '80' => 'vcrun2005',
          '90' => 'vcrun2008',
          _ => null,
        };
        if (id == null || !dependencyTable.any((row) => row.id == id)) continue;
        final mfc = assembly.endsWith('.mfc');
        add(
          id,
          arch,
          mfc ? Need.recommended : Need.optional,
          mfc ? NeedReason.notInWine : NeedReason.imported,
          assembly,
        );
      }
    }
  }
  for (final id in fix?.requires ?? const <String>[]) {
    if (archFor(id, arch) case final at?) {
      add(id, at, Need.recommended, NeedReason.knownFix, null);
    }
  }
  final order = [for (final row in dependencyTable) row.id];
  return (
    key: app.key,
    dependencies: needs.values.toList()
      ..sort((a, b) => order.indexOf(a.id).compareTo(order.indexOf(b.id))),
    settings: [
      if (fix != null)
        for (final step in fix.steps)
          if (step.type == 'ini' && step.applies)
            (
              fix: fix.id,
              section: step.section!,
              name: step.name!,
              value: step.data!,
              state: fixStepState(home, bottle, step),
            ),
    ],
  );
}

/// D6: installs runtime [id] for [arch] in the bottle from its files: [files],
/// in the order of the row's downloads, or else the downloads into
/// `downloads/`, which matching files already there save. Each must match its
/// pinned SHA-256. Refused while the bottle runs: an install replaces DLLs
/// that a game may hold, and the overrides reach only processes that start
/// afterwards. Then, by kind (design §4): `run` runs each file headless, after
/// Wine Mono leaves for .NET and with the bottle's Windows version for the
/// run when the row says so; `cab` takes files out of the cabinets with Wine's
/// own `extrac32` and copies them in; `copy` writes the one file at its
/// marker. Wine's own manifests that would make an installer skip its
/// assemblies wait outside the prefix during the run, and go back if anything
/// fails. The whole install has the row's time limit, past which the bottle
/// stops and [InstallTimedOut] is thrown. The overrides are written after a
/// good run only, "installed" is read from the bottle after it, and it returns
/// once Wine's server is gone, so that a queue's next item does not find the
/// bottle open. Returns the last step's log.
Future<String> installDependency(
  String home,
  String bottle,
  String id,
  String arch, {
  List<String>? files,
}) async {
  final (row, pin) = _dependencyFile(id, arch);
  final dir = _existing(home, bottle);
  final prefix = '$dir/prefix';
  if (!_ready(prefix)) throw BottleNotReady(bottle);
  if (_installedRuntime(home, dir) case final rt?
      when await _serverRunning(rt, dir)) {
    throw BottleOpen(bottle);
  }
  if (files != null && files.length != pin.downloads.length) {
    throw BadChoice(ChoiceKind.dependency, '$id $arch');
  }
  final paths = <String>[];
  for (final (i, download) in pin.downloads.indexed) {
    final path =
        files?[i] ??
        await _download(
          home,
          download.url,
          download.sha256,
          name: download.file,
        );
    if (FileSystemEntity.typeSync(path) != FileSystemEntityType.file) {
      throw MissingFile(path);
    }
    if (await sha256Of(path) != download.sha256) throw ChecksumMismatch(path);
    paths.add(path);
  }

  final deadline = DateTime.now().add(Duration(minutes: pin.minutes));
  var log = '';
  Duration left() {
    final time = deadline.difference(DateTime.now());
    return time.isNegative ? Duration.zero : time;
  }

  Future<Never> late() async {
    await stopBottle(home, bottle);
    throw InstallTimedOut(id, arch, log);
  }

  /// Runs [program] headless and waits until the bottle is idle, within the
  /// time limit; its exit code.
  Future<int> step(String program, List<String> args) async {
    log = await _launchIn(
      home,
      bottle,
      program,
      args,
      backend: 'wine',
      label: '$id-$arch',
    );
    final code = await exitOf(log).timeout(left(), onTimeout: late);
    await waitBottle(home, bottle).timeout(left(), onTimeout: late);
    return code;
  }

  final manifests = '$prefix/drive_c/windows/winsxs/manifests';
  final aside = Directory('$dir/wine-manifests');
  final moved = <String>[
    for (final pattern in pin.wineManifests)
      for (final path in _markerFiles(
        '$prefix/drive_c',
        'windows/winsxs/manifests/$pattern',
      ))
        path.split('/').last,
  ];
  if (moved.isNotEmpty) aside.createSync(recursive: true);
  for (final name in moved) {
    File('$manifests/$name').renameSync('${aside.path}/$name');
  }
  var installed = false;
  var windowsSet = false;
  try {
    switch (pin.kind) {
      case DependencyKind.run:
        if (pin.replacesMono) {
          for (final product in _monoProducts(prefix)) {
            final code = await step('msiexec', ['/x', product, '/q']);
            if (code != 0) throw WineToolFailed(WineTool.installer, code, log);
          }
          for (final folder in ['system32', 'syswow64']) {
            final dll = '$prefix/drive_c/windows/$folder/mscoree.dll';
            if (FileSystemEntity.typeSync(dll, followLinks: false) ==
                    FileSystemEntityType.file &&
                !_isVendors(dll)) {
              File(dll).deleteSync();
            }
          }
        }
        if (pin.windowsDuring case final version?) {
          windowsSet = true;
          final code = await step('winecfg', ['-v', version]);
          if (code != 0) throw WineToolFailed(WineTool.winecfg, code, log);
        }
        for (final path in paths) {
          if (row.windows case final version?) {
            await _reg(home, bottle, [
              'add',
              'HKCU\\Software\\Wine\\AppDefaults\\${path.split('/').last}',
              '/v',
              'Version',
              '/t',
              'REG_SZ',
              '/d',
              version,
              '/f',
            ]);
          }
          final code = await step(path, pin.args);
          if (!_installerOk.contains(code)) {
            throw WineToolFailed(WineTool.installer, code, log);
          }
        }
      case DependencyKind.cab:
        await _installCab(prefix, id, arch, pin, paths, step, () => log);
      case DependencyKind.copy:
        _writeOver(paths.single, '$prefix/drive_c/${pin.marker}');
    }
    for (final dll in row.dlls) {
      // A copy runs nothing in Wine: its log is the overrides'.
      final regLog = await _reg(home, bottle, [
        'add',
        r'HKCU\Software\Wine\DllOverrides',
        '/v',
        dll,
        '/t',
        'REG_SZ',
        '/d',
        'native,builtin',
        '/f',
      ]);
      if (log.isEmpty) log = regLog;
    }
    if (!dependencyInstalled(home, bottle, id, arch)) {
      throw DependencyNotInstalled(id, arch, log);
    }
    installed = true;
    return log;
  } finally {
    // Back where they were, unless the installer wrote one of the same name;
    // after a good install, the vendor's stand in their place.
    for (final name in moved) {
      final saved = File('${aside.path}/$name');
      if (!installed && !File('$manifests/$name').existsSync()) {
        saved.renameSync('$manifests/$name');
      } else {
        saved.deleteSync();
      }
    }
    if (aside.existsSync() && aside.listSync().isEmpty) aside.deleteSync();
    if (windowsSet) {
      // The bottle's own version again, outside the time limit, which may be
      // the reason this runs.
      await waitBottle(home, bottle);
      await exitOf(
        await _launchIn(
          home,
          bottle,
          'winecfg',
          ['-v', _settings(dir).windows],
          backend: 'wine',
          label: 'windows',
        ),
      );
    }
    await waitBottle(home, bottle);
  }
}

/// The `cab` kind (design §4, S2): each file's cabinet is cut from its first
/// header into `windows/temp/bodega-<id>`, opened there by Wine's `extrac32`,
/// then the inner cabinets that match `cabs`; the files that match `take` go
/// into `into` in lowercase, `register` runs the arch's `regsvr32` on the DLLs
/// that match it, and `fonts` are registered as winetricks does. Each Wine
/// step is one batch file, so Wine starts once per step. The folder goes
/// whatever happens.
Future<void> _installCab(
  String prefix,
  String id,
  String arch,
  DependencyFile pin,
  List<String> paths,
  Future<int> Function(String, List<String>) step,
  String Function() log,
) async {
  final temp = Directory('$prefix/drive_c/windows/temp/bodega-$id');
  final win = 'C:\\windows\\temp\\bodega-$id';

  Future<void> batch(List<String> lines) async {
    File(
      '${temp.path}/run.bat',
    ).writeAsStringSync(lines.map((line) => '$line || exit /b 1\r\n').join());
    final code = await step('cmd', ['/c', '$win\\run.bat']);
    if (code != 0) throw WineToolFailed(WineTool.installer, code, log());
  }

  if (temp.existsSync()) temp.deleteSync(recursive: true);
  temp.createSync(recursive: true);
  try {
    for (final (i, path) in paths.indexed) {
      if (!_cutCabinet(path, '${temp.path}/$i.cab')) {
        throw DependencyNotInstalled(id, arch, path);
      }
    }
    await batch([
      for (var i = 0; i < paths.length; i++)
        'extrac32 /y /e /l $win\\outer $win\\$i.cab',
    ]);
    var from = '${temp.path}/outer';
    if (pin.cabs.isNotEmpty) {
      final inner = [
        for (final name in _realFiles(from))
          if (pin.cabs.any((cab) => _nameMatches(name, cab))) name,
      ]..sort();
      await batch([
        for (final name in inner)
          'extrac32 /y /e /l $win\\inner $win\\outer\\$name',
      ]);
      from = '${temp.path}/inner';
    }
    final into = '$prefix/drive_c/${pin.into}';
    if (FileSystemEntity.typeSync(into, followLinks: false) ==
        FileSystemEntityType.notFound) {
      Directory(into).createSync(recursive: true);
    }
    if (!_isRealDirectory(into)) throw UnexpectedLink(into);
    final copied = <String>[];
    for (final name in _realFiles(from)) {
      if (!pin.take.any((take) => _nameMatches(name, take))) continue;
      _writeOver('$from/$name', '$into/${name.toLowerCase()}');
      copied.add(name.toLowerCase());
    }
    copied.sort();
    final folder = pin.into.replaceAll('/', '\\');
    final register = [
      for (final name in copied)
        if (pin.register.any((pattern) => _nameMatches(name, pattern))) name,
    ];
    if (register.isNotEmpty) {
      await batch([
        for (final name in register) 'C:\\$folder\\regsvr32.exe /s $name',
      ]);
    }
    final faces = [
      for (final name in copied)
        if (pin.fonts[name] case final face?) (name, face),
    ];
    if (faces.isNotEmpty) {
      final values = [
        for (final (name, face) in faces) '"$face (TrueType)"="$name"',
      ].join('\r\n');
      File('${temp.path}/fonts.reg').writeAsStringSync(
        'REGEDIT4\r\n\r\n'
        '[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts]\r\n'
        '$values\r\n\r\n'
        '[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows\\CurrentVersion\\Fonts]\r\n'
        '$values\r\n',
      );
      final code = await step('regedit', ['/S', '$win\\fonts.reg']);
      if (code != 0) throw WineToolFailed(WineTool.reg, code, log());
    }
  } finally {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  }
}

/// Writes [path]'s cabinet, from its first `MSCF` header to the end, to [to]:
/// Wine's `extrac32` opens a cabinet, not the self-extracting program around
/// it (T2). False when there is no header.
bool _cutCabinet(String path, String to) {
  const magic = [0x4D, 0x53, 0x43, 0x46, 0, 0, 0, 0];
  const chunk = 1 << 20;
  final input = File(path).openSync();
  try {
    final length = input.lengthSync();
    var offset = -1;
    for (var at = 0; at < length && offset < 0; at += chunk - magic.length) {
      input.setPositionSync(at);
      final bytes = input.readSync(chunk);
      for (var i = 0; i + magic.length <= bytes.length && offset < 0; i++) {
        var j = 0;
        while (j < magic.length && bytes[i + j] == magic[j]) {
          j++;
        }
        if (j == magic.length) offset = at + i;
      }
      if (bytes.length < chunk) break;
    }
    if (offset < 0) return false;
    final output = File(to).openSync(mode: FileMode.write);
    try {
      input.setPositionSync(offset);
      for (
        var bytes = input.readSync(chunk);
        bytes.isNotEmpty;
        bytes = input.readSync(chunk)
      ) {
        output.writeFromSync(bytes);
      }
    } finally {
      output.closeSync();
    }
    return true;
  } finally {
    input.closeSync();
  }
}

/// The names of the regular files in [dir], no link followed.
List<String> _realFiles(String dir) => [
  if (_isRealDirectory(dir))
    for (final entry in Directory(dir).listSync(followLinks: false))
      if (FileSystemEntity.typeSync(entry.path, followLinks: false) ==
          FileSystemEntityType.file)
        entry.path.split('/').last,
];

/// [from]'s bytes at [to], through a file beside it renamed over it, in a
/// real folder and never through a link.
void _writeOver(String from, String to) {
  final folder = File(to).parent.path;
  if (!_isRealDirectory(folder)) throw UnexpectedLink(folder);
  if (FileSystemEntity.typeSync(to, followLinks: false) ==
      FileSystemEntityType.link) {
    throw UnexpectedLink(to);
  }
  File(from).copySync('$to.bodega-part');
  File('$to.bodega-part').renameSync(to);
}

/// The product codes of Wine Mono in the prefix's `system.reg`, read from the
/// `Uninstall` keys whose display name starts with "Wine Mono" (S3).
Set<String> _monoProducts(String prefix) {
  final file = File('$prefix/system.reg');
  if (!file.existsSync()) return const {};
  final found = <String>{};
  String? product;
  for (final line in file.readAsLinesSync(encoding: latin1)) {
    if (line.startsWith('[')) {
      product = RegExp(r'\\\\Uninstall\\\\(\{[0-9A-Fa-f-]{36}\})\]')
          .firstMatch(line)?[1];
    } else if (product != null && line.startsWith('"DisplayName"="Wine Mono')) {
      found.add(product);
    }
  }
  return found;
}

/// `reg` with [args] in the bottle, headless; a failure throws (F3). Its log.
Future<String> _reg(String home, String bottle, List<String> args) async {
  final log = await _launchIn(home, bottle, 'reg', args, backend: 'wine');
  final code = await exitOf(log);
  if (code != 0) throw WineToolFailed(WineTool.reg, code, log);
  return log;
}

/// The size of [bytes] as the CLI prints it: megabytes with one decimal.
String megabytes(int bytes) => '${(bytes / 1000000).toStringAsFixed(1)} MB';

/// `bodega deps <args>` (D11): the work of the verb [args] names, which writes
/// its output to [out] and gives the exit code, or null for a bad usage, which
/// the CLI answers with its usage before it touches anything.
Future<int> Function(String home)? depsVerb(
  List<String> args,
  StringSink out,
) => switch (args) {
  ['list', final bottle] => (home) async {
    for (final line in bottleDependencies(home, bottle)) {
      final (row, pin) = _dependencyFile(line.id, line.arch);
      out.writeln(switch (line.installed) {
        true => '${row.id} ${line.arch} installed',
        false => '${row.id} ${line.arch} not installed ${megabytes(pin.bytes)}',
        null => '${row.id} ${line.arch} unknown',
      });
    }
    return 0;
  },
  ['check', final bottle, final key] => (home) async {
    final needs = await appNeeds(home, bottle, key);
    needs.dependencies.map(needLine).forEach(out.writeln);
    needs.settings.map(settingLine).forEach(out.writeln);
    if (needs.dependencies.isEmpty && needs.settings.isEmpty) {
      out.writeln('nothing to propose');
    }
    return 0;
  },
  ['install', final bottle, final id, final arch, ...final files]
      when const ['x86', 'x64', 'all'].contains(arch) =>
    (home) async {
      out.writeln(
        'log: ${await installDependency(home, bottle, id, arch, files: files.isEmpty ? null : files)}',
      );
      return 0;
    },
  _ => null,
};

/// One line of `deps check` for [need].
String needLine(DependencyNeed need) {
  final why = switch (need.reason) {
    NeedReason.knownFix => 'fix ${need.fix}',
    NeedReason.notInWine => 'imports ${need.dll}, which Wine lacks',
    NeedReason.imported => 'imports ${need.dll}',
  };
  return '${need.need.name} ${need.id} ${need.arch} ($why)'
      '${switch (need.installed) {
        true => ' installed',
        false => '',
        null => ' unknown',
      }}';
}

/// One line of `deps check` for [setting].
String settingLine(SettingNeed setting) =>
    'setting [${setting.section}] ${setting.name}=${setting.value} '
    '${switch (setting.state) {
      SettingState.applied => 'applied',
      SettingState.notApplied => 'not applied',
      SettingState.noFile => 'no file yet: open the game once',
    }} (fix ${setting.fix})';
