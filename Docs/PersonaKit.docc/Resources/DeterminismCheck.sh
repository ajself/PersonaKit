swift run personakit export --root ./MyKit --persona senior-swiftui-engineer --task apply-style > /tmp/session1.md
swift run personakit export --root ./MyKit --persona senior-swiftui-engineer --task apply-style > /tmp/session2.md
cmp /tmp/session1.md /tmp/session2.md
