const fs = require('fs');
let code = fs.readFileSync('server.js', 'utf8');

// 1. Direct messages
code = code.replace(
    'const savedMessage = await newMessage.save();\r\n        res.json(savedMessage);',
    `const savedMessage = await newMessage.save();
        await savedMessage.populate('sender', 'username profilePicture displayName');
        const io = req.app.get('io');
        if (io) {
            io.to(receiver).emit('new_message', savedMessage);
            io.to(sender).emit('new_message', savedMessage);
        }
        res.json(savedMessage);`.replace(/\n/g, '\r\n')
);

// Fallback for LF
code = code.replace(
    'const savedMessage = await newMessage.save();\n        res.json(savedMessage);',
    `const savedMessage = await newMessage.save();
        await savedMessage.populate('sender', 'username profilePicture displayName');
        const io = req.app.get('io');
        if (io) {
            io.to(receiver).emit('new_message', savedMessage);
            io.to(sender).emit('new_message', savedMessage);
        }
        res.json(savedMessage);`
);

// 2. Group messages
code = code.replace(
    'const msg = await newMessage.save();\r\n        await msg.populate(\'sender\', \'username profilePicture displayName\');\r\n        \r\n        res.json(msg);',
    `const msg = await newMessage.save();
        await msg.populate('sender', 'username profilePicture displayName');
        const io = req.app.get('io');
        if (io) {
            io.to(req.params.groupId).emit('new_group_message', msg);
        }
        res.json(msg);`.replace(/\n/g, '\r\n')
);

// Fallback for LF
code = code.replace(
    'const msg = await newMessage.save();\n        await msg.populate(\'sender\', \'username profilePicture displayName\');\n        \n        res.json(msg);',
    `const msg = await newMessage.save();
        await msg.populate('sender', 'username profilePicture displayName');
        const io = req.app.get('io');
        if (io) {
            io.to(req.params.groupId).emit('new_group_message', msg);
        }
        res.json(msg);`
);

fs.writeFileSync('server.js', code);
console.log('Patched server.js successfully.');
