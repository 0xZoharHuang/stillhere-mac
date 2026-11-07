# 在场壁纸库：灵感与生成记录

图库图片为本项目新生成的原创插画，采用职场常见梗的语气，并非下载、重贴社交媒体用户的图片。原有的「我司雇我在」提示词见 `wallpaper-prompt.txt`。

公开检索中，X、Instagram、Threads 和小红书的单条帖子不总是能在无需登录时完整访问；本记录不把无法直接核实的内容写成具体平台帖子的引用。2026 年 11 月检索到 X 关于多窗口 AI 编程梗的公开摘要，但原帖及图片未能独立核实；Instagram 搜索没有得到可直接核实、可复用的具体帖子。我们只吸收话题和幽默结构，没有下载或重贴社交媒体图片。灵感参考：

- [小红书上的职场自嘲和「发疯工牌」报道](https://www.thepaper.cn/newsDetail_forward_28086167)：以日常工作的荒诞感做自嘲。
- [会议本可是一封邮件：职场表达](https://www.bbc.co.uk/learningenglish/english/features/office-english)及[会议与邮件梗的讨论](https://www.flowtrace.co/collaboration-blog/this-meeting-could-have-been-an-email-unraveling-the-truth-behind-the-meme)：会议信息过载与邮件的反差。前者为 BBC Office English 系列，后者为梗的解释。
- [开发者讨论 AI、调试和上下文](https://www.reddit.com/r/ProgrammerHumor/comments/1xfwotk/thisisverytrue/)及[人和 coding agent 的对话](https://www.reddit.com/r/ProgrammerHumor/comments/1wpr37x/everydiscussionwiththecodingagent/)：参考开发者对 AI 交互、调试与反复沟通的日常幽默，不复制原图或帖子文案。
- [人和代码有一个能跑就行](https://linux.do/t/topic/2508620)：开发者讨论里明确将代码运行与人跑路放在一起；本项目的「我和代码，总有一个能跑」由用户提出，画面为原创。
- [一个小改动引发的 AI 重构讨论](https://www.reddit.com/r/ProgrammerHumor/comments/1kvlj4m/thebeautifulcode/)及[重新打开自己以前的代码](https://www.reddit.com/r/ProgrammerHumor/comments/slt0cy/when_you_opened_the_code_you_wrote_two_weeks_ago/)：参考真实开发场景中的反差，文案和插画重新创作。
- [UU 远程自定义隐私屏的用户玩法](https://bbs.huaweicloud.com/blogs/477825)：参考离席画面作为个性化、社交化表达的使用场景；不使用或模仿 UU 的具体图像。

新一轮的原创图和 5 张旧图字幕修订的提示词见 [bilingual-wallpaper-prompts.md](bilingual-wallpaper-prompts.md)；后续根据实际笑点重新创作的版本见 [refinement-prompts.md](refinement-prompts.md)。完整交付列表见 [壁纸目录](../docs/WALLPAPERS.md)。早期原图保留在 [legacy-wallpapers](legacy-wallpapers/)；下方记录为历史版本。

## 图片与提示词

- `MeetingEmail.png`：原创复古印刷风，蓝黑米色会议室，严肃西装鸽子拿信封、长桌上的鸽子昏昏欲睡；文字「这个会本来可以是封邮件」与英文副标题。
- `AwayWorking.png`：原创复古旅行海报风，热带海滩上的西装水豚休息，友好小机器人继续操作桌面；文字「人在休息，活在运行」与英文副标题。
- `QuietOffice.png`：原创深蓝夜间电影海报风，透明罩里闭目休息的橘猫，发光鼠标指针继续工作；文字「正在装作不在工位」与英文副标题。
- `InboxReply.png`：复古海报里的橘猫面对源源不断的邮件小鸟，文字「已读，乱回」。
- `FishMode.png`：水墨海报里的锦鲤老板和水下办公室，文字「正在认真摸鱼」。
- `LoadingDog.png`：陷入 99% 加载的金毛办公室职员，文字「精神状态：加载中」。
- `PieReserve.png`：浣熊打开装满画饼的冰箱，文字「老板画的饼，先放冰箱」。

图片使用内置 imagegen 按上述场景、横版桌面壁纸、中文标题和无水印要求生成，原图保存在仓库资源目录中。

### 完整生成提示词

**MeetingEmail**

> Create an original wide landscape 16:9 desktop wallpaper meme for a witty Chinese Mac privacy app. Editorial risograph illustration in a restrained ink-black, warm cream and cobalt palette. A hilariously serious pigeon in business attire solemnly presents a single tiny envelope to an absurdly long boardroom table occupied by sleepy little pigeons; cinematic negative space. Large perfectly legible simplified Chinese text verbatim: “这个会本来可以是封邮件”. Small English line: “THIS COULD HAVE BEEN AN EMAIL”. Wry and stylish, not childish; original artwork, no logos, no watermark.

**AwayWorking**

> Create an original wide landscape 16:9 desktop wallpaper meme for a privacy app. Luxury editorial illustration / retro travel poster, warm butter yellow, dark forest green, terracotta; serene capybara in a business suit dozes in a deck chair on a tiny island while a miniature friendly robot diligently tends a glowing desktop terminal beside it, visual joke that automation keeps working while human is away. Large perfectly legible simplified Chinese words verbatim: “人在休息，活在运行”. Small English line “OUT OF OFFICE, NOT OUT OF WORK”. Beautiful typography, quiet confident negative space, original characters, no logos or watermark.

**QuietOffice**

> Create an original wide landscape 16:9 desktop wallpaper meme for a witty privacy utility. Minimal dark ink-blue evening scene with a comically solemn tiny orange office cat in a necktie powering down inside a glass dome as a glowing robot cursor continues typing at a terminal, cinematic graphic poster, modern Swiss editorial typography, soft warm highlights and lots of deep navy negative space. Large clearly readable simplified Chinese text verbatim “正在装作不在工位”. Small English line “CURRENTLY ELSEWHERE”. Original artwork, polished, funny deadpan, no logo, no watermark.
