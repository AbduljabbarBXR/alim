/// One hundred turns to Allah spoken inside the Qur'an, kept in mushaf order.
class DuaEntry {
  const DuaEntry({
    required this.title,
    required this.surah,
    required this.ayah,
    required this.who,
    required this.category,
    required this.story,
  });

  final String title;
  final int surah;
  final int ayah;
  final String who;
  final String category;
  final String story;

  String get source => 'Qur\'an $surah:$ayah';
}

const duaCategories = <String>[
  'Guidance',
  'Forgiveness',
  'Mercy',
  'Family',
  'Provision',
  'Protection',
  'Patience',
  'Gratitude',
  'Faith',
  'Hereafter',
  'Community',
  'Praise',
];

const duas = <DuaEntry>[
  DuaEntry(
    title: 'You alone we worship',
    surah: 1,
    ayah: 5,
    who: 'The servant',
    category: 'Faith',
    story:
        'The opening of the Book teaches the heart to speak to Allah directly: '
        'worship, trust and the help we ask belong to Him alone.',
  ),
  DuaEntry(
    title: 'Glory to You, we know only what You taught',
    surah: 2,
    ayah: 32,
    who: 'The angels',
    category: 'Praise',
    story:
        'When Allah told the angels of His plan for the earth, they answered '
        'with humility, leaving knowledge to Him.',
  ),
  DuaEntry(
    title: 'A safe city',
    surah: 2,
    ayah: 126,
    who: 'Ibrahim',
    category: 'Provision',
    story:
        'Ibrahim asked Allah to make the city safe and to feed its believing '
        'people with the fruits of the earth.',
  ),
  DuaEntry(
    title: 'While raising the House',
    surah: 2,
    ayah: 127,
    who: 'Ibrahim and Isma\'il',
    category: 'Gratitude',
    story:
        'They built the Kaaba with their hands and asked Allah to accept it. '
        'He accepted their work and raised a prophet from their line.',
  ),
  DuaEntry(
    title: 'Make us submitters',
    surah: 2,
    ayah: 128,
    who: 'Ibrahim and Isma\'il',
    category: 'Faith',
    story:
        'Father and son asked to remain surrendered to Allah and to raise a '
        'nation that would do the same.',
  ),
  DuaEntry(
    title: 'Send them a messenger',
    surah: 2,
    ayah: 129,
    who: 'Ibrahim and Isma\'il',
    category: 'Guidance',
    story:
        'They asked Allah to send a messenger from among their descendants to '
        'teach the Book and purify them.',
  ),
  DuaEntry(
    title: 'To Allah we belong',
    surah: 2,
    ayah: 156,
    who: 'The believers at loss',
    category: 'Patience',
    story:
        'When loss reaches them, the believers answer with these words and ask '
        'for mercy and guidance in return.',
  ),
  DuaEntry(
    title: 'Good in both worlds',
    surah: 2,
    ayah: 201,
    who: 'The believers',
    category: 'Hereafter',
    story:
        'A short and balanced prayer, asking for good in this life and the '
        'next, and protection from the Fire.',
  ),
  DuaEntry(
    title: 'Patience and firm feet',
    surah: 2,
    ayah: 250,
    who: 'Talut and his companions',
    category: 'Patience',
    story:
        'Facing a larger army, they asked for patience and for their feet to '
        'stay firm.',
  ),
  DuaEntry(
    title: 'Show me how You give life',
    surah: 2,
    ayah: 260,
    who: 'Ibrahim',
    category: 'Faith',
    story:
        'Ibrahim asked to see with his own eyes how Allah brings the dead to '
        'life, and Allah answered his heart.',
  ),
  DuaEntry(
    title: 'We hear and we obey',
    surah: 2,
    ayah: 285,
    who: 'The believers',
    category: 'Faith',
    story:
        'The believers accept what has been sent down and ask forgiveness, '
        'knowing that every return is to Allah.',
  ),
  DuaEntry(
    title: 'Do not burden us',
    surah: 2,
    ayah: 286,
    who: 'The believers',
    category: 'Mercy',
    story:
        'A prayer for pardon, mercy and help when memory or strength fails, '
        'ending with trust in Allah alone.',
  ),
  DuaEntry(
    title: 'Do not let our hearts swerve',
    surah: 3,
    ayah: 8,
    who: 'The believers',
    category: 'Guidance',
    story:
        'After guidance, the heart still needs Allah. They ask Him to keep it '
        'steady and to grant mercy.',
  ),
  DuaEntry(
    title: 'You will gather mankind',
    surah: 3,
    ayah: 9,
    who: 'The believers',
    category: 'Hereafter',
    story:
        'They remember the Day when every person will stand before Allah and '
        'ask for the promise of mercy.',
  ),
  DuaEntry(
    title: 'We have believed, so forgive us',
    surah: 3,
    ayah: 16,
    who: 'The believers',
    category: 'Forgiveness',
    story:
        'A short confession of faith joined to a plea for pardon and shelter '
        'from the Fire.',
  ),
  DuaEntry(
    title: 'Master of all dominion',
    surah: 3,
    ayah: 26,
    who: 'The Prophet, peace be upon him',
    category: 'Praise',
    story:
        'Allah gives power and takes it, honours and humbles. The prayer '
        'leaves all of that in His hands.',
  ),
  DuaEntry(
    title: 'A child devoted to You',
    surah: 3,
    ayah: 35,
    who: 'The wife of Imran',
    category: 'Family',
    story:
        'She dedicated the child in her womb to Allah and asked Him to accept '
        'her offering.',
  ),
  DuaEntry(
    title: 'I place her in Your care',
    surah: 3,
    ayah: 36,
    who: 'The wife of Imran',
    category: 'Protection',
    story:
        'When Mary was born, her mother asked Allah to guard her and her '
        'descendants from harm.',
  ),
  DuaEntry(
    title: 'A child in old age',
    surah: 3,
    ayah: 38,
    who: 'Zakariya',
    category: 'Family',
    story:
        'Standing in the prayer niche, he asked for a good offspring. Allah '
        'gave him Yahya, though he was old and his wife could not bear.',
  ),
  DuaEntry(
    title: 'A sign in silence',
    surah: 3,
    ayah: 41,
    who: 'Zakariya',
    category: 'Guidance',
    story:
        'Zakariya asked for a sign, and Allah gave him silence for three days '
        'as a mark of the answer.',
  ),
  DuaEntry(
    title: 'Write us among the witnesses',
    surah: 3,
    ayah: 53,
    who: 'The disciples',
    category: 'Faith',
    story:
        'The disciples believed in what was sent down and asked to be recorded '
        'among those who bear witness.',
  ),
  DuaEntry(
    title: 'Forgive our sins and steady our feet',
    surah: 3,
    ayah: 147,
    who: 'The steadfast',
    category: 'Forgiveness',
    story:
        'After hardship, they asked for pardon, for their steps to hold, and '
        'for help against those who reject faith.',
  ),
  DuaEntry(
    title: 'Allah is sufficient for us',
    surah: 3,
    ayah: 173,
    who: 'The believers after Uhud',
    category: 'Faith',
    story:
        'When warned that armies had gathered, their faith grew and they '
        'placed their affairs with Allah.',
  ),
  DuaEntry(
    title: 'Not in vain did You create this',
    surah: 3,
    ayah: 191,
    who: 'People of understanding',
    category: 'Praise',
    story:
        'They remember Allah standing, sitting and lying down, and see purpose '
        'in the heavens and the earth.',
  ),
  DuaEntry(
    title: 'We have heard, so forgive us',
    surah: 3,
    ayah: 193,
    who: 'People of understanding',
    category: 'Forgiveness',
    story:
        'They answer the call to faith and ask for forgiveness, mercy and a '
        'place among the righteous.',
  ),
  DuaEntry(
    title: 'Give us what You promised',
    surah: 3,
    ayah: 194,
    who: 'People of understanding',
    category: 'Hereafter',
    story:
        'They ask Allah for what He promised through His messengers and for '
        'protection from disgrace.',
  ),
  DuaEntry(
    title: 'Save us from the oppressive town',
    surah: 4,
    ayah: 75,
    who: 'The weak and oppressed',
    category: 'Protection',
    story:
        'The cry of those trapped by tyranny: send a protector, and bring us '
        'out into safety.',
  ),
  DuaEntry(
    title: 'Write us among the witnesses',
    surah: 5,
    ayah: 83,
    who: 'The faithful of the Book',
    category: 'Faith',
    story:
        'Hearing the truth, their eyes fill with tears and they ask to be '
        'counted among its witnesses.',
  ),
  DuaEntry(
    title: 'A table from heaven',
    surah: 5,
    ayah: 114,
    who: 'Isa',
    category: 'Provision',
    story:
        'Isa asked Allah for a table as a sign and a provision, and Allah '
        'answered with His bounty.',
  ),
  DuaEntry(
    title: 'Forgive us and have mercy',
    surah: 5,
    ayah: 118,
    who: 'Isa',
    category: 'Forgiveness',
    story:
        'Isa leaves judgment to Allah and asks for forgiveness and mercy for '
        'those who follow him.',
  ),
  DuaEntry(
    title: 'My prayer and my sacrifice',
    surah: 6,
    ayah: 162,
    who: 'The Prophet, peace be upon him',
    category: 'Faith',
    story:
        'A whole life offered to Allah: prayer, sacrifice, living and dying '
        'belong to the Lord of the worlds.',
  ),
  DuaEntry(
    title: 'Words after the fall',
    surah: 7,
    ayah: 23,
    who: 'Adam and Hawwa',
    category: 'Forgiveness',
    story:
        'They turned back to Allah after eating from the tree. He taught them '
        'the words of repentance and accepted them.',
  ),
  DuaEntry(
    title: 'Do not place us with the wrongdoers',
    surah: 7,
    ayah: 47,
    who: 'The people of the heights',
    category: 'Protection',
    story:
        'Seeing the fate of the unjust, the people on the heights ask Allah '
        'not to join them with the wrongdoers.',
  ),
  DuaEntry(
    title: 'Judge between us in truth',
    surah: 7,
    ayah: 89,
    who: 'Shu\'ayb',
    category: 'Guidance',
    story:
        'When his people threatened him, Shu\'ayb asked Allah to judge with '
        'truth and to keep him on the right path.',
  ),
  DuaEntry(
    title: 'Pour patience upon us',
    surah: 7,
    ayah: 126,
    who: 'The believers before Pharaoh',
    category: 'Patience',
    story:
        'Under threat of torture, they asked for patience and to leave this '
        'life as those who submit.',
  ),
  DuaEntry(
    title: 'Show me Yourself',
    surah: 7,
    ayah: 143,
    who: 'Musa',
    category: 'Faith',
    story:
        'Musa asked for a glimpse of Allah. The mountain crumbled at the '
        'sight, and he turned in repentance and faith.',
  ),
  DuaEntry(
    title: 'Forgive me and my brother',
    surah: 7,
    ayah: 151,
    who: 'Musa',
    category: 'Forgiveness',
    story:
        'Musa asked mercy for himself and Harun, and for both to enter the '
        'mercy of Allah.',
  ),
  DuaEntry(
    title: 'You are our protector, so forgive us',
    surah: 7,
    ayah: 155,
    who: 'Musa',
    category: 'Mercy',
    story:
        'After the people faltered, Musa asked Allah, their protector, to '
        'forgive them and have mercy.',
  ),
  DuaEntry(
    title: 'Ordain for us good',
    surah: 7,
    ayah: 156,
    who: 'Musa',
    category: 'Mercy',
    story:
        'A prayer for good in this world and the next, with the admission that '
        'all matters return to Allah.',
  ),
  DuaEntry(
    title: 'A righteous child',
    surah: 7,
    ayah: 189,
    who: 'Adam and Hawwa',
    category: 'Family',
    story:
        'When a child was given to them, they asked Allah to make that child '
        'righteous and grateful.',
  ),
  DuaEntry(
    title: 'Do not make us a trial',
    surah: 10,
    ayah: 85,
    who: 'The believers with Musa',
    category: 'Protection',
    story:
        'They asked Allah not to let their suffering become a reason for '
        'oppressors to boast or for others to lose faith.',
  ),
  DuaEntry(
    title: 'Against the tyrant\'s grip',
    surah: 10,
    ayah: 88,
    who: 'Musa',
    category: 'Protection',
    story:
        'Under Pharaoh\'s oppression, Musa asked Allah to strip the tyrant of '
        'power so the truth could be seen.',
  ),
  DuaEntry(
    title: 'Forgive me for what I do not know',
    surah: 11,
    ayah: 47,
    who: 'Nuh',
    category: 'Forgiveness',
    story:
        'When Nuh pleaded for his son without knowledge, Allah corrected him, '
        'and he asked forgiveness.',
  ),
  DuaEntry(
    title: 'Turn away their plot',
    surah: 12,
    ayah: 33,
    who: 'Yusuf',
    category: 'Protection',
    story:
        'Yusuf preferred prison to sin and asked Allah to turn the women\'s '
        'plot away from him.',
  ),
  DuaEntry(
    title: 'Join me with the righteous',
    surah: 12,
    ayah: 101,
    who: 'Yusuf',
    category: 'Hereafter',
    story:
        'At the height of his power, Yusuf asked to die as a submitter and to '
        'join the righteous.',
  ),
  DuaEntry(
    title: 'Make this city safe',
    surah: 14,
    ayah: 35,
    who: 'Ibrahim',
    category: 'Protection',
    story:
        'Ibrahim asked Allah to keep the city safe and to turn its people away '
        'from idol worship.',
  ),
  DuaEntry(
    title: 'Provide them with fruits',
    surah: 14,
    ayah: 37,
    who: 'Ibrahim',
    category: 'Provision',
    story:
        'Ibrahim settled his family in a barren valley and asked Allah to draw '
        'hearts to them and provide for them.',
  ),
  DuaEntry(
    title: 'You know what we conceal',
    surah: 14,
    ayah: 38,
    who: 'Ibrahim',
    category: 'Faith',
    story:
        'Nothing is hidden from Allah, and Ibrahim rested in that knowledge '
        'with gratitude.',
  ),
  DuaEntry(
    title: 'Praise for a late gift',
    surah: 14,
    ayah: 39,
    who: 'Ibrahim',
    category: 'Gratitude',
    story:
        'In old age Ibrahim praised Allah for Isma\'il and Ishaq, and prayed '
        'that his descendants would keep the prayer.',
  ),
  DuaEntry(
    title: 'Make me steadfast in prayer',
    surah: 14,
    ayah: 40,
    who: 'Ibrahim',
    category: 'Faith',
    story:
        'Ibrahim asked Allah to make him and his descendants constant in '
        'prayer and to accept his call.',
  ),
  DuaEntry(
    title: 'Forgive me and my parents',
    surah: 14,
    ayah: 41,
    who: 'Ibrahim',
    category: 'Forgiveness',
    story:
        'A prayer that joins personal need with love for parents and for all '
        'the believers.',
  ),
  DuaEntry(
    title: 'Have mercy on them',
    surah: 17,
    ayah: 24,
    who: 'The child of parents',
    category: 'Family',
    story:
        'A tender prayer for parents, spoken with humility and remembered from '
        'childhood.',
  ),
  DuaEntry(
    title: 'A truthful entrance and exit',
    surah: 17,
    ayah: 80,
    who: 'The Prophet, peace be upon him',
    category: 'Guidance',
    story:
        'A prayer that every coming and going be accompanied by truth, light '
        'and help from Allah.',
  ),
  DuaEntry(
    title: 'Shelter in the cave',
    surah: 18,
    ayah: 10,
    who: 'The young men of the cave',
    category: 'Protection',
    story:
        'They fled their people for their faith and asked for mercy and '
        'guidance. Allah sheltered them and kept them safe for years.',
  ),
  DuaEntry(
    title: 'Remember your Lord when you forget',
    surah: 18,
    ayah: 24,
    who: 'The believer',
    category: 'Faith',
    story:
        'The Qur\'an teaches that when the future is uncertain, the heart '
        'should say: perhaps Allah will guide us to what is nearer.',
  ),
  DuaEntry(
    title: 'What Allah wills',
    surah: 18,
    ayah: 39,
    who: 'The owner of the garden',
    category: 'Gratitude',
    story:
        'A reminder to credit every blessing to Allah and to refuse the pride '
        'that turns a gift into a test.',
  ),
  DuaEntry(
    title: 'My bones are weak',
    surah: 19,
    ayah: 4,
    who: 'Zakariya',
    category: 'Family',
    story:
        'Zakariya described his frailty and his wife\'s age, then asked Allah '
        'for a successor who would carry the faith.',
  ),
  DuaEntry(
    title: 'A tongue for the truth',
    surah: 20,
    ayah: 25,
    who: 'Musa',
    category: 'Guidance',
    story:
        'Sent to Pharaoh, he asked for an open chest and an easy task. Allah '
        'answered and made Harun his helper.',
  ),
  DuaEntry(
    title: 'We fear Pharaoh',
    surah: 20,
    ayah: 45,
    who: 'Musa and Harun',
    category: 'Protection',
    story:
        'Sent to the tyrant, Musa and Harun admitted their fear. Allah '
        'answered: do not fear, I am with you both.',
  ),
  DuaEntry(
    title: 'A request for knowledge',
    surah: 20,
    ayah: 114,
    who: 'The Prophet, peace be upon him',
    category: 'Guidance',
    story:
        'Allah taught His Prophet this single request to keep repeating: more '
        'knowledge, taken with humility.',
  ),
  DuaEntry(
    title: 'When illness would not leave',
    surah: 21,
    ayah: 83,
    who: 'Ayyub',
    category: 'Patience',
    story:
        'He lost his health, his family and his wealth, and still he called '
        'Allah the Most Merciful. Allah removed the harm and restored him.',
  ),
  DuaEntry(
    title: 'From the belly of the whale',
    surah: 21,
    ayah: 87,
    who: 'Yunus',
    category: 'Mercy',
    story:
        'In the darkness of the whale he called with these words. Allah '
        'answered and saved him, and then guided the people of Nineveh.',
  ),
  DuaEntry(
    title: 'Do not leave me alone',
    surah: 21,
    ayah: 89,
    who: 'Zakariya',
    category: 'Family',
    story:
        'Zakariya asked for an heir, not to hoard a blessing, but so the '
        'worship of Allah would continue.',
  ),
  DuaEntry(
    title: 'Judge between us in truth',
    surah: 21,
    ayah: 112,
    who: 'The Prophet, peace be upon him',
    category: 'Guidance',
    story:
        'When opposition grew, the Prophet placed the matter with Allah, the '
        'Most Merciful, and asked for truth to prevail.',
  ),
  DuaEntry(
    title: 'Help me, for they deny me',
    surah: 23,
    ayah: 26,
    who: 'Nuh',
    category: 'Protection',
    story:
        'Nuh asked Allah for help when his people rejected him and turned away '
        'from the warning.',
  ),
  DuaEntry(
    title: 'Land us in a blessed place',
    surah: 23,
    ayah: 29,
    who: 'Nuh',
    category: 'Provision',
    story:
        'After the flood, Nuh asked Allah to bring the ark to rest in a place '
        'full of blessing and safety.',
  ),
  DuaEntry(
    title: 'Do not place me with the wrongdoers',
    surah: 23,
    ayah: 94,
    who: 'The Prophet, peace be upon him',
    category: 'Protection',
    story:
        'A prayer for distance from injustice and from the company of those '
        'who practise it.',
  ),
  DuaEntry(
    title: 'When the whisper comes',
    surah: 23,
    ayah: 97,
    who: 'The believers',
    category: 'Protection',
    story:
        'A shelter for the heart when the devils stir doubt. It is followed by '
        'the same refuge in the next ayah.',
  ),
  DuaEntry(
    title: 'Forgive and have mercy',
    surah: 23,
    ayah: 118,
    who: 'The Prophet, peace be upon him',
    category: 'Forgiveness',
    story:
        'A short prayer that gathers the whole need of the heart: pardon, '
        'mercy and trust in Allah.',
  ),
  DuaEntry(
    title: 'Turn away the punishment of Hell',
    surah: 25,
    ayah: 65,
    who: 'The servants of the Most Merciful',
    category: 'Hereafter',
    story:
        'They walk humbly and ask Allah to spare them the lasting punishment '
        'of the Fire.',
  ),
  DuaEntry(
    title: 'Comfort at home',
    surah: 25,
    ayah: 74,
    who: 'The servants of the Most Merciful',
    category: 'Family',
    story:
        'They ask for spouses and children who are a comfort, and for a life '
        'that leads others toward what is good.',
  ),
  DuaEntry(
    title: 'Grant me wisdom',
    surah: 26,
    ayah: 83,
    who: 'Ibrahim',
    category: 'Guidance',
    story:
        'Ibrahim asked for wisdom, for a place among the righteous and for a '
        'good name among later generations.',
  ),
  DuaEntry(
    title: 'Forgive my father',
    surah: 26,
    ayah: 86,
    who: 'Ibrahim',
    category: 'Forgiveness',
    story:
        'A son\'s prayer for his father. The Qur\'an leaves the final judgment '
        'with Allah and shows that guidance belongs to Him.',
  ),
  DuaEntry(
    title: 'Do not disgrace me on the Day',
    surah: 26,
    ayah: 87,
    who: 'Ibrahim',
    category: 'Hereafter',
    story:
        'Ibrahim asked that the Day of Resurrection bring honour, not shame, '
        'and that none of his family be disgraced.',
  ),
  DuaEntry(
    title: 'My people have denied me',
    surah: 26,
    ayah: 117,
    who: 'Nuh',
    category: 'Protection',
    story:
        'Nuh placed the rejection of his people before Allah and asked for a '
        'decisive judgment between them.',
  ),
  DuaEntry(
    title: 'Save me and my family',
    surah: 26,
    ayah: 169,
    who: 'Lut',
    category: 'Protection',
    story:
        'Lut asked Allah to save him and his family from the corruption that '
        'surrounded them.',
  ),
  DuaEntry(
    title: 'Gratitude for a small thing',
    surah: 27,
    ayah: 19,
    who: 'Sulayman',
    category: 'Gratitude',
    story:
        'He smiled at the speech of an ant and asked to be grateful for what '
        'he had been given. Allah gave him a kingdom unlike any after him.',
  ),
  DuaEntry(
    title: 'I have wronged myself, forgive me',
    surah: 28,
    ayah: 16,
    who: 'Musa',
    category: 'Forgiveness',
    story:
        'After the blow that killed the Egyptian, Musa admitted his fault and '
        'asked Allah to forgive him.',
  ),
  DuaEntry(
    title: 'Never a helper to criminals',
    surah: 28,
    ayah: 17,
    who: 'Musa',
    category: 'Faith',
    story:
        'Forgiven and blessed, Musa promised to keep his strength away from '
        'wrongdoing.',
  ),
  DuaEntry(
    title: 'Save me from the wrongdoing people',
    surah: 28,
    ayah: 21,
    who: 'Musa',
    category: 'Protection',
    story:
        'Fleeing Egypt, Musa asked Allah to deliver him from a people who '
        'would not let him live.',
  ),
  DuaEntry(
    title: 'I need whatever good You send',
    surah: 28,
    ayah: 24,
    who: 'Musa',
    category: 'Provision',
    story:
        'After helping the two women at the well, Musa turned to Allah with an '
        'open hand and an empty pocket.',
  ),
  DuaEntry(
    title: 'Help me against the corrupt',
    surah: 29,
    ayah: 30,
    who: 'Lut',
    category: 'Protection',
    story:
        'Lut asked Allah for help against a people who spread corruption and '
        'refused every warning.',
  ),
  DuaEntry(
    title: 'Grant me a righteous child',
    surah: 37,
    ayah: 100,
    who: 'Ibrahim',
    category: 'Family',
    story:
        'Ibrahim asked for a child who would be righteous, and Allah gave him '
        'Isma\'il.',
  ),
  DuaEntry(
    title: 'A kingdom unlike any after me',
    surah: 38,
    ayah: 35,
    who: 'Sulayman',
    category: 'Provision',
    story:
        'Sulayman asked for a kingdom that would show Allah\'s favour and '
        'become a means of gratitude and service.',
  ),
  DuaEntry(
    title: 'You know the unseen',
    surah: 39,
    ayah: 46,
    who: 'The Prophet, peace be upon him',
    category: 'Faith',
    story:
        'A prayer that places every hidden matter with Allah, the Knower of '
        'the unseen and the seen.',
  ),
  DuaEntry(
    title: 'Forgive those who repent',
    surah: 40,
    ayah: 7,
    who: 'The angels',
    category: 'Forgiveness',
    story:
        'The angels who carry the throne ask forgiveness for the believers and '
        'for those who turn back to Allah.',
  ),
  DuaEntry(
    title: 'Admit them to the gardens',
    surah: 40,
    ayah: 8,
    who: 'The angels',
    category: 'Hereafter',
    story:
        'They ask Allah to bring the believers into the gardens of Eden, '
        'together with the righteous among their families.',
  ),
  DuaEntry(
    title: 'Protect them from evil deeds',
    surah: 40,
    ayah: 9,
    who: 'The angels',
    category: 'Protection',
    story:
        'A prayer that the believers be shielded from the consequences of evil '
        'and from disgrace on the Day of Account.',
  ),
  DuaEntry(
    title: 'Glory to Him who made this subject to us',
    surah: 43,
    ayah: 13,
    who: 'The traveler',
    category: 'Gratitude',
    story:
        'A prayer for the road: the vehicle, the journey and the safe arrival '
        'are all signs of Allah\'s care.',
  ),
  DuaEntry(
    title: 'To our Lord we will return',
    surah: 43,
    ayah: 14,
    who: 'The traveler',
    category: 'Hereafter',
    story:
        'The journey reminds the heart that every road ends in a return to '
        'Allah.',
  ),
  DuaEntry(
    title: 'Remove the punishment from us',
    surah: 44,
    ayah: 12,
    who: 'The people of Pharaoh',
    category: 'Mercy',
    story:
        'Under punishment, Pharaoh\'s people promised faith if it was lifted. '
        'The Qur\'an warns that a prayer in hardship must become a real turn.',
  ),
  DuaEntry(
    title: 'Thank You for Your favor',
    surah: 46,
    ayah: 15,
    who: 'The grateful child',
    category: 'Gratitude',
    story:
        'At forty, a person is taught to thank Allah, to do good and to ask '
        'for righteous descendants.',
  ),
  DuaEntry(
    title: 'I am overcome, so help me',
    surah: 54,
    ayah: 10,
    who: 'Nuh',
    category: 'Protection',
    story:
        'Nuh called out when his people rejected him, and Allah answered with '
        'a deliverance that none could resist.',
  ),
  DuaEntry(
    title: 'Forgive us and our brothers',
    surah: 59,
    ayah: 10,
    who: 'The believers',
    category: 'Community',
    story:
        'A prayer for those who came before, for forgiveness, and for a heart '
        'free of resentment.',
  ),
  DuaEntry(
    title: 'We rely on You and turn to You',
    surah: 60,
    ayah: 4,
    who: 'Ibrahim and the believers',
    category: 'Faith',
    story:
        'A declaration of trust in Allah alone, with repentance and a final '
        'return to Him.',
  ),
  DuaEntry(
    title: 'Do not make us a trial',
    surah: 60,
    ayah: 5,
    who: 'Ibrahim and the believers',
    category: 'Protection',
    story:
        'They asked Allah not to let their faith become a cause for the '
        'disbelievers to mock or for the believers to falter.',
  ),
  DuaEntry(
    title: 'Perfect our light for us',
    surah: 66,
    ayah: 8,
    who: 'The believers',
    category: 'Hereafter',
    story:
        'The believers ask for a light that will guide them on the Day when '
        'the hypocrites are left in darkness.',
  ),
  DuaEntry(
    title: 'Forgive me, my parents and the believers',
    surah: 71,
    ayah: 28,
    who: 'Nuh',
    category: 'Community',
    story:
        'Nuh closes his call with a prayer for himself, his parents and every '
        'believer, men and women.',
  ),
  DuaEntry(
    title: 'Refuge in the Lord of the daybreak',
    surah: 113,
    ayah: 1,
    who: 'The Prophet, peace be upon him',
    category: 'Protection',
    story:
        'A shelter from every harm that comes with the night, the knots of '
        'envy and the darkness of jealousy.',
  ),
  DuaEntry(
    title: 'Refuge in the Lord of mankind',
    surah: 114,
    ayah: 1,
    who: 'The Prophet, peace be upon him',
    category: 'Protection',
    story:
        'The final surah asks Allah to guard the heart from the whisperer who '
        'slips away and returns.',
  ),
];
