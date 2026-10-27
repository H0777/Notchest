#!/usr/bin/env python3
"""Render the bilingual, dependency-free GitHub Pages feature gallery."""
from pathlib import Path
import argparse, html, json
ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / 'site'
FEATURES = json.loads((SITE / 'features.json').read_text())
REPO = 'https://github.com/H0777/Notchest'
HOME = 'https://h0777.github.io/Notchest/'
DOWNLOAD = REPO + '/releases/download/v0.5.0/Notchest-0.5.0.dmg'
def esc(value): return html.escape(str(value), quote=True)
def render(ar=False):
    language = 'ar' if ar else 'en'
    def t(en, arabic): return arabic if ar else en
    def field(item, key): return item[key + '_ar'] if ar else item[key]
    categories = [('all', t('All features', 'كل الميزات')),('everyday',t('Everyday','يومك')),('developer',t('Developer','المطوّر')),('ai',t('AI usage','استخدام AI')),('utilities',t('Mac utilities','أدوات الماك')),('personal',t('Make it yours','التخصيص'))]
    filters = ''.join(f'<button class="filter" data-filter="{key}" aria-pressed="{str(key=="all").lower()}">{label}</button>' for key,label in categories)
    cards = []
    for number,item in enumerate(FEATURES,1):
        title,description,note = [field(item,k) for k in ['title','description','note']]
        cards.append(f'''<article class="feature-card" id="{item['id']}" data-category="{item['category']}" data-title="{esc(title+' '+description)}">
          <button class="capture-button" data-open="{item['id']}" aria-label="{esc(t('Enlarge: ','تكبير: ')+title)}"><img src="assets/screenshots/{item['image']}.jpg" alt="{esc(t('Actual Notchest interface: ','واجهة Notchest الفعلية: ')+title)}" width="1516" height="1088" loading="lazy" decoding="async"><span class="expand-icon" aria-hidden="true">↗</span></button>
          <div class="feature-copy"><span class="feature-number">{number:02d} / {esc(dict(categories)[item['category']])}</span><h3>{esc(title)}</h3><p>{esc(description)}</p><div class="feature-note"><span aria-hidden="true">↳</span> {esc(note)}</div></div>
        </article>''')
    schema = {'@context':'https://schema.org','@type':'SoftwareApplication','name':'Notchest','applicationCategory':'UtilitiesApplication','operatingSystem':'macOS','softwareVersion':'0.5.0','url':HOME,'downloadUrl':DOWNLOAD,'license':REPO+'/blob/main/LICENSE','description':t('A native Mac island for focus, developer tools, AI usage, and daily utilities.','جزيرة ماك أصلية للتركيز وأدوات المطور واستخدام الذكاء الاصطناعي وأدواتك اليومية.')}
    return f'''<!doctype html>
<html lang="{language}" dir="{'rtl' if ar else 'ltr'}">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{t('Notchest — Your tools. A little closer.','Notchest — أدواتك، أقرب.')}</title>
<meta name="description" content="{esc(schema['description'])}">
<meta name="theme-color" content="#090b13">
<link rel="canonical" href="{HOME+('ar.html' if ar else '')}">
<link rel="alternate" hreflang="en" href="{HOME}"><link rel="alternate" hreflang="ar" href="{HOME}ar.html"><link rel="alternate" hreflang="x-default" href="{HOME}">
<link rel="icon" href="icon.png" type="image/png">
<meta property="og:type" content="website"><meta property="og:site_name" content="Notchest"><meta property="og:title" content="Notchest — {esc(t('Your tools. A little closer.','أدواتك، أقرب.'))}"><meta property="og:description" content="{esc(schema['description'])}"><meta property="og:url" content="{HOME+('ar.html' if ar else '')}"><meta property="og:image" content="{HOME}assets/social-preview.png"><meta property="og:image:width" content="1200"><meta property="og:image:height" content="630"><meta name="twitter:card" content="summary_large_image"><meta name="twitter:image" content="{HOME}assets/social-preview.png">
<link rel="stylesheet" href="style.css"><script defer src="app.js"></script>
<script type="application/ld+json">{json.dumps(schema, ensure_ascii=False)}</script>
</head>
<body class="landing">
<a class="skip-link" href="#main">{t('Skip to content','انتقل إلى المحتوى')}</a>
<header class="topbar"><a class="wordmark" href="{'ar.html' if ar else 'index.html'}" aria-label="Notchest {t('home','الرئيسية')}"><img src="icon.png" width="38" height="38" alt=""><span>Notchest<span class="wordmark-dot">.</span></span></a><nav aria-label="{t('Main navigation','التنقل الرئيسي')}"><a class="nav-secondary" href="#features">{t('Explore','استكشف')}</a><a class="nav-secondary" href="{'guide-ar.html' if ar else 'guide.html'}">{t('Guide','الدليل')}</a><a href="{REPO}">GitHub <span aria-hidden="true">↗</span></a><a class="language-switch" href="{'index.html' if ar else 'ar.html'}" lang="{'en' if ar else 'ar'}">{'English' if ar else 'العربية'}</a></nav></header>
<main id="main">
<section class="hero-section shell">
  <div class="release-pill"><span class="status-dot"></span>{t('Made for Mac · Open source','صُمّم للماك · مفتوح المصدر')}<span class="pill-divider">/</span>0.5.0</div>
  <h1>{t('Your tools.<br><span>A little closer.</span>','أدواتك اليومية.<br><span>أعلى الشاشة.</span>')}</h1>
  <p class="hero-description">{t('A small island for the things you reach for.<br>Focus, build, and keep your day in flow.','جزيرة صغيرة للأدوات التي تحتاجها.<br>ركّز، وأنجز، واجعل يومك أكثر انسيابًا.')}</p>
  <div class="hero-actions"><a class="button button-primary" href="{DOWNLOAD}"><span aria-hidden="true">↓</span> {t('Download for Mac','تحميل للماك')}</a><a class="button button-secondary" href="#features">{t('Explore all features','استكشف كل الميزات')} <span aria-hidden="true">↗</span></a></div>
  <p class="download-meta">{t('Apple Silicon · macOS 13+ target · Free & open source','Apple Silicon · يستهدف macOS 13+ · مجاني ومفتوح المصدر')}</p>
  <figure class="hero-capture"><div class="capture-topline"><span class="capture-dot"></span><span>{t('A real app. A little more possibility.','تطبيق أصلي. إمكانات أقرب.')}</span><span class="capture-label">{t('ACTUAL INTERFACE','الواجهة الفعلية')}</span></div><a href="#features"><img src="assets/screenshots/overview.jpg" width="1516" height="1088" alt="{t('Notchest overview with colorful tool cards and curved notch shoulders','الصفحة الرئيسية في Notchest ببطاقات ملونة وانحناءات النوتش')}" fetchpriority="high" decoding="async"></a><figcaption>{t('Captured from the running app. Documentation previews use clearly labeled sample data.','صور من التطبيق أثناء تشغيله. تستخدم معاينات التوثيق بيانات توضيحية موسومة بوضوح.')}</figcaption></figure>
  <figure class="hero-capture"><div class="capture-topline"><span class="capture-dot"></span><span>{t('Watch it move.','شاهده يتحرك.')}</span><span class="capture-label">{t('SCREEN RECORDING','تسجيل شاشة حقيقي')}</span></div><img src="assets/demo.gif" width="800" height="702" alt="{t('A real screen recording of the Notchest island','تسجيل شاشة حقيقي لجزيرة Notchest')}" loading="lazy" decoding="async"></figure>
</section>
<div class="principles shell"><span><i class="principle-dot cyan"></i>{t('Native SwiftUI + AppKit','SwiftUI وAppKit أصلية')}</span><span><i class="principle-dot violet"></i>{t('Local tools, optional connections','أدوات محلية، واتصالات اختيارية')}</span><span><i class="principle-dot rose"></i>{t('English + العربية','الإنجليزية + العربية')}</span></div>
<section class="feature-section shell" id="features"><div class="section-heading"><div><p class="eyebrow">{t('SMALL SPACE. MANY POSSIBILITIES.','مساحة صغيرة. إمكانات كثيرة.')}</p><h2>{t('A place for every little thing.','مكان لكل أداة تحتاجها.')}</h2></div><p>{t('Browse '+str(len(FEATURES))+' features, see the actual interface,<br>and find out how each one works.','تصفح '+str(len(FEATURES))+' ميزة، وشاهد واجهتها الفعلية،<br>وتعرّف على طريقة استخدامها.')}</p></div>
<div class="gallery-toolbar"><div class="filters" role="group" aria-label="{t('Filter features','تصفية الميزات')}">{filters}</div><label class="gallery-search"><span aria-hidden="true">⌕</span><input id="feature-search" type="search" placeholder="{t('Find a feature…','ابحث عن ميزة…')}" aria-label="{t('Search features','البحث عن الميزات')}"></label></div>
<p class="gallery-caption">{t('Select any screenshot to zoom in. Captures use illustrative data; setup requirements are explained below.','انقر أي صورة لتكبيرها. تستخدم الصور بيانات توضيحية، وتجد متطلبات الإعداد أسفل كل ميزة.')}</p>
<div class="feature-grid">{''.join(cards)}</div><p class="empty-state" hidden>{t('No features found. Try another word.','لا توجد نتائج. جرّب كلمة أخرى.')}</p><div class="gallery-more"><button class="button button-secondary" id="show-more" hidden>{t('Show all 39 features','عرض الميزات الـ39 كلها')} <span aria-hidden="true">↓</span></button><p class="result-count" aria-live="polite"></p></div></section>
<section class="install-section shell" id="install"><div class="install-copy"><p class="eyebrow">{t('A FEW SECONDS FROM HERE','خطوات قليلة وتبدأ')}</p><h2>{t('A small home<br>on your Mac.','مكان صغير<br>على جهازك.')}</h2><p>{t('Download the disk image, drag Notchest into Applications, and make the island yours.','حمّل صورة القرص، واسحب Notchest إلى Applications، واضبط الجزيرة على طريقتك.')}</p><a class="button button-primary" href="{DOWNLOAD}">{t('Get Notchest 0.5','احصل على Notchest 0.5')} <span aria-hidden="true">↗</span></a><p class="release-note">{t('Development release · not yet Developer-ID signed or notarized.','إصدار تطوير · لم يُوقّع بعد بهوية Developer ID أو يُصدّق من Apple.')} <a href="{REPO}/releases/latest">{t('Release notes','ملاحظات الإصدار')}</a></p></div><div class="install-steps"><article><span>01</span><div><h3>{t('Download','حمّل التطبيق')}</h3><p>{t('A DMG for the familiar Mac experience, or a portable ZIP from Releases.','DMG لتجربة الماك المعتادة، أو ZIP محمول من صفحة الإصدارات.')}</p></div></article><article><span>02</span><div><h3>{t('Make it yours','اضبطه على طريقتك')}</h3><p>{t('Choose your display, island size, colors, and preferred language.','اختر الشاشة والحجم والألوان ولغة الواجهة.')}</p></div></article><article><span>03</span><div><h3>{t('Connect what you need','اربط ما تحتاجه')}</h3><p>{t('Optional services and macOS permissions are explained in the feature guide.','يوضح دليل الميزات الخدمات الاختيارية وصلاحيات macOS المطلوبة.')}</p></div></article></div></section>
<section class="faq-section shell"><p class="eyebrow">{t('GOOD TO KNOW','معلومات مفيدة')}</p><h2>{t('The details, without the noise.','التفاصيل التي تهمك.')}</h2><details><summary>{t('Which Mac and macOS versions?','ما الأجهزة والأنظمة المطلوبة؟')}</summary><p>{t('The packaged build is for Apple Silicon. Source targets macOS 13+, with Apple Translation on 15+ and Liquid Glass on 26+. Earlier-system and Intel validation remain on the roadmap.','الحزمة مخصصة لـApple Silicon. يستهدف المصدر macOS 13+؛ الترجمة تحتاج 15+ وLiquid Glass يحتاج 26+. اختبار الأنظمة الأقدم وIntel ما زال ضمن خطة العمل.')}</p></details><details><summary>{t('Does everything need an account?','هل تحتاج كل أداة إلى حساب؟')}</summary><p>{t('No. Notes, focus, code transforms, and other local tools work without one. GitHub, account limits, stocks, music, and other connected tools have their own setup requirements.','لا. الملاحظات والتركيز وتحويلات الكود والأدوات المحلية تعمل دون حساب. للأدوات المتصلة مثل GitHub وحدود الحساب والأسهم والموسيقى متطلبات إعداد منفصلة.')}</p></details><details><summary>{t('Are these screenshots real?','هل هذه صور حقيقية من التطبيق؟')}</summary><p>{t('Yes. They are captures of the running SwiftUI/AppKit interface in an isolated documentation build. Example notes, usage, system readings, track details, and task events are labeled sample data. No personal accounts, camera, or private clipboard were used.','نعم. هي لقطات لواجهة SwiftUI وAppKit أثناء التشغيل في نسخة توثيق منفصلة. الملاحظات والاستخدام وقراءات النظام والموسيقى وأحداث المهام أمثلة موسومة بوضوح. لم تُستخدم حسابات شخصية أو الكاميرا أو الحافظة الخاصة.')}</p></details><details><summary>{t('Can I build it myself?','هل يمكنني بناءه بنفسي؟')}</summary><p>{t('Absolutely. The project is MIT licensed. Use Xcode 26+ or Swift tools with the macOS 26 SDK, then follow the repository build instructions.','بالتأكيد. المشروع بترخيص MIT. استخدم Xcode 26+ أو أدوات Swift مع SDK macOS 26، واتبع تعليمات البناء في المستودع.')} <a href="{REPO}#build-from-source">{t('Build instructions','تعليمات البناء')} ↗</a></p></details></section>
</main>
<footer class="site-footer shell"><a class="wordmark" href="{'ar.html' if ar else 'index.html'}">Notchest<span class="wordmark-dot">.</span></a><p>{t('A little more useful. A little more you.','أدوات أقرب. مساحة تشبهك.')}</p><nav aria-label="{t('Footer links','روابط إضافية')}"><a href="{REPO}">GitHub</a><a href="{'guide-ar.html' if ar else 'guide.html'}">{t('Feature guide','دليل الميزات')}</a><a href="{REPO}/blob/main/ROADMAP.md">{t('Roadmap','خطة العمل')}</a><a href="{REPO}/blob/main/LICENSE">MIT</a></nav></footer>
<dialog id="feature-dialog" aria-labelledby="dialog-title"><div class="dialog-toolbar"><div><span class="eyebrow">{t('INSIDE NOTCHEST','داخل NOTCHEST')}</span><h2 id="dialog-title"></h2></div><button id="dialog-close" aria-label="{t('Close preview','إغلاق المعاينة')}">×</button></div><img id="dialog-image" src="assets/screenshots/overview.jpg" alt=""><div class="dialog-caption"><p id="dialog-description"></p><p id="dialog-note"></p><a class="dialog-original" id="dialog-original" href="assets/screenshots/overview.jpg" target="_blank" rel="noopener">{t("Open full-resolution image ↗","افتح الصورة بالدقة الكاملة ↗")}</a></div><div class="dialog-navigation"><button id="dialog-prev" aria-label="{t('Previous feature','الميزة السابقة')}">←</button><span id="dialog-position"></span><button id="dialog-next" aria-label="{t('Next feature','الميزة التالية')}">→</button></div></dialog>
</body></html>'''

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
    for name,ar in [('index.html',False),('ar.html',True)]:
        output=render(ar)
        if args.check:
            assert (SITE/name).read_text()==output, f'{name} is stale; run python3 Scripts/build-site.py'
        else: (SITE/name).write_text(output)
    print(('Checked' if args.check else 'Rendered')+f' two languages and {len(FEATURES)} feature cards.')
if __name__=='__main__': main()
