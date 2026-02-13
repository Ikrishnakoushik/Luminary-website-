const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const path = require('path');
const fs = require('fs'); // Import fs
const User = require('./models/User');
const Post = require('./models/Post');
const seedData = require('./seed'); // Import seed script

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'your_jwt_secret_key_here';
const nodemailer = require('nodemailer');

// Nodemailer Transporter (Configure with your email service)
const transporter = nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 465,
    secure: true, // Use SSL
    auth: {
        user: 'meta81210@gmail.com',
        pass: 'zidl aiex mtza umao',
    }
});

// Ensure uploads directory exists
const uploadDir = path.join(__dirname, 'public/uploads');
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

// Middleware
app.use(cors({
    origin: '*', // Allow all origins (including file://)
    methods: ['GET', 'POST', 'PUT', 'DELETE'],
    allowedHeaders: ['Content-Type', 'x-auth-token']
}));
app.use(express.json());
// Request Logger
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
    next();
});
app.use(express.static(path.join(__dirname, 'public')));
const auth = (req, res, next) => {
    const token = req.header('x-auth-token');
    if (!token) return res.status(401).json({ msg: 'No token, authorization denied' });

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded.user;
        next();
    } catch (err) {
        res.status(401).json({ msg: 'Token is not valid' });
    }
};

// Database Connection
const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/everything_spread';
mongoose.connect(MONGO_URI)
    .then(() => console.log('MongoDB Connected'))
    .catch(err => console.log(err));

// Routes
const multer = require('multer');

// Configure Multer Storage
const storage = multer.diskStorage({
    destination: './public/uploads/',
    filename: function (req, file, cb) {
        cb(null, 'avatar-' + Date.now() + path.extname(file.originalname));
    }
});

const upload = multer({
    storage: storage,
    limits: { fileSize: 5000000 }, // 5MB limit
    fileFilter: function (req, file, cb) {
        checkFileType(file, cb);
    }
});

// Check File Type
function checkFileType(file, cb) {
    // Allowed ext
    const filetypes = /jpeg|jpg|png|gif|pdf|doc|docx/;
    // Check ext
    const extname = filetypes.test(path.extname(file.originalname).toLowerCase());
    // Check mime
    const mimetype = filetypes.test(file.mimetype);

    if (mimetype && extname) {
        return cb(null, true);
    } else {
        cb('Error: Images, PDFs and Documents Only!');
    }
}

// Upload Avatar Route
app.post('/api/users/avatar', auth, (req, res) => {
    upload.single('avatar')(req, res, async (err) => {
        if (err) {
            return res.status(400).json({ msg: err });
        } else {
            if (req.file == undefined) {
                return res.status(400).json({ msg: 'No file selected!' });
            } else {
                try {
                    // Update user profile with image path
                    // Path should be relative to public folder: /uploads/filename
                    const imagePath = `/uploads/${req.file.filename}`;

                    const user = await User.findById(req.user.id);
                    user.profilePicture = imagePath;
                    await user.save();

                    res.json({
                        msg: 'File Uploaded!',
                        filePath: imagePath
                    });
                } catch (error) {
                    console.error(error);
                    res.status(500).send('Server Error');
                }
            }
        }
    });
});

// Register
app.post('/api/register', async (req, res) => {
    try {
        console.log('Register request received:', req.body);
        const { username, email, password, role } = req.body;

        // Check if user exists
        let user = await User.findOne({ email });
        if (user) {
            return res.status(400).json({ msg: 'User already exists' });
        }

        // Hash password
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        // Validate role
        const validRoles = ['publisher', 'reader'];
        const userRole = validRoles.includes(role) ? role : 'reader';

        // Generate 6-digit OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();



        // Create user with isVerified: false
        user = new User({
            username,
            email,
            password: hashedPassword,
            role: userRole,
            isVerified: false,
            verificationOtp: otp,
            verificationExpires: Date.now() + 10 * 60 * 1000 // 10 minutes
        });

        await user.save();

        // Send Verification Email
        const mailOptions = {
            from: process.env.EMAIL_USER || 'no-reply@prism.com',
            to: user.email,
            subject: 'Prism - Verify Your Email',
            text: `Welcome to Prism! Please verify your email using this OTP: ${otp}\n\nIt expires in 10 minutes.`
        };

        transporter.sendMail(mailOptions, (error, info) => {
            if (error) {
                console.error('Error sending verification email:', error);
                return res.status(500).json({ msg: 'Error sending verification email. User registered but not verified.' });
            } else {
                console.log('Verification email sent: ' + info.response);
                res.status(201).json({ msg: 'Verification required', email: user.email });
            }
        });

    } catch (err) {
        console.log('Error in register route:', err);
        console.error(err);
        res.status(500).send('Server Error: ' + err.message);
    }
});

// Verify Email
app.post('/api/verify-email', async (req, res) => {
    try {
        const { email, otp } = req.body;
        const user = await User.findOne({
            email,
            verificationOtp: otp,
            verificationExpires: { $gt: Date.now() }
        });

        if (!user) {
            return res.status(400).json({ msg: 'Invalid or expired OTP' });
        }

        user.isVerified = true;
        user.verificationOtp = undefined;
        user.verificationExpires = undefined;
        await user.save();

        // Return Token (Login successful)
        const payload = {
            user: {
                id: user.id,
                username: user.username,
                role: user.role
            }
        };

        jwt.sign(
            payload,
            JWT_SECRET,
            { expiresIn: '1h' },
            (err, token) => {
                if (err) throw err;
                res.json({ token, username: user.username, role: user.role });
            }
        );

    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// Forgot Password (Send OTP)
app.post('/api/auth/forgot-password', async (req, res) => {
    try {
        const { email } = req.body;
        const user = await User.findOne({ email });

        if (!user) {
            return res.status(404).json({ msg: 'User with this email does not exist' });
        }

        // Generate 6-digit OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();

        // Save OTP and expiration (10 minutes)
        user.resetPasswordOtp = otp;
        user.resetPasswordExpires = Date.now() + 10 * 60 * 1000;
        await user.save();



        // Send Email
        console.log(`[DEBUG] Sending Forgot Password OTP to ${user.email}`);
        const mailOptions = {
            from: process.env.EMAIL_USER || 'no-reply@prism.com',
            to: user.email,
            subject: 'Prism - Password Reset OTP',
            text: `Your OTP for password reset is: ${otp}\n\nIt expires in 10 minutes.`
        };

        transporter.sendMail(mailOptions, (error, info) => {
            if (error) {
                console.error('[DEBUG] Error sending email:', error);
                return res.status(500).json({ msg: 'Error sending email. Please check server logs and credentials.' });
            } else {
                console.log('[DEBUG] Email sent: ' + info.response);
                res.json({ msg: 'OTP sent to email', email: user.email });
            }
        });

    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// Reset Password (Verify OTP and Update)
app.post('/api/auth/reset-password', async (req, res) => {
    try {
        const { email, otp, newPassword } = req.body;

        console.log(`[DEBUG] Reset attempt for: ${email} with OTP: ${otp}`);

        // Debug: Find user by email first to see what's in DB
        const debugUser = await User.findOne({ email });
        if (debugUser) {
            console.log(`[DEBUG] DB User found. Stored OTP: ${debugUser.resetPasswordOtp}, Expires: ${debugUser.resetPasswordExpires}, Now: ${Date.now()}`);
        } else {
            console.log(`[DEBUG] No user found with email: ${email}`);
        }

        const user = await User.findOne({
            email,
            resetPasswordOtp: otp,
            resetPasswordExpires: { $gt: Date.now() } // Check if not expired
        });

        if (!user) {
            console.log('[DEBUG] OTP Verification Failed');
            return res.status(400).json({ msg: 'Invalid or expired OTP' });
        }

        // Hash new password
        const salt = await bcrypt.genSalt(10);
        user.password = await bcrypt.hash(newPassword, salt);

        // Clear OTP fields
        user.resetPasswordOtp = undefined;
        user.resetPasswordExpires = undefined;
        await user.save();

        res.json({ msg: 'Password reset successful. Please login.' });

    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// Login
app.post('/api/login', async (req, res) => {
    try {
        const { email, password } = req.body;

        // Check if user exists
        const user = await User.findOne({ email });
        if (!user) {
            return res.status(400).json({ msg: 'Invalid Credentials' });
        }

        // Validate password
        const isMatch = await bcrypt.compare(password, user.password);

        if (!isMatch) {
            return res.status(400).json({ msg: 'Invalid Credentials' });
        }

        // Log visit
        user.loginHistory.push(new Date());
        await user.save();

        // Return token
        const payload = {
            user: {
                id: user.id,
                username: user.username,
                role: user.role
            }
        };

        jwt.sign(
            payload,
            JWT_SECRET,
            { expiresIn: '1h' },
            (err, token) => {
                if (err) throw err;
                res.json({ token, username: user.username, role: user.role });
            }
        );
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// Update Profile Info
app.put('/api/users/profile', auth, async (req, res) => {
    try {
        const { displayName, bio, username, email } = req.body;

        // Build update object
        const updateFields = {};
        if (displayName) updateFields.displayName = displayName;
        if (bio) updateFields.bio = bio;
        if (username) updateFields.username = username;
        if (email) updateFields.email = email;

        // Check if username/email already taken (if changed)
        if (username || email) {
            const existingUser = await User.findOne({
                $or: [{ email }, { username }],
                _id: { $ne: req.user.id } // Exclude current user
            });
            if (existingUser) {
                return res.status(400).json({ msg: 'Username or Email already in use' });
            }
        }

        const user = await User.findByIdAndUpdate(
            req.user.id,
            { $set: updateFields },
            { new: true }
        ).select('-password');

        res.json(user);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// Update Password
app.put('/api/users/password', auth, async (req, res) => {
    try {
        const { currentPassword, newPassword } = req.body;

        const user = await User.findById(req.user.id);

        // Verify current password
        const isMatch = await bcrypt.compare(currentPassword, user.password);
        if (!isMatch) {
            return res.status(400).json({ msg: 'Incorrect current password' });
        }

        // Hash new password
        const salt = await bcrypt.genSalt(10);
        user.password = await bcrypt.hash(newPassword, salt);
        await user.save();

        res.json({ msg: 'Password updated successfully' });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// Update Preferences
app.put('/api/users/preferences', auth, async (req, res) => {
    try {
        const { preferences } = req.body;
        const user = await User.findById(req.user.id);

        user.preferences = preferences;
        await user.save();

        res.json({ msg: 'Preferences updated', preferences: user.preferences });
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// Get User by ID (Public Profile)
app.get('/api/users/:id', async (req, res) => {
    try {
        const user = await User.findById(req.params.id).select('-password');
        if (!user) return res.status(404).json({ msg: 'User not found' });
        res.json(user);
    } catch (err) {
        console.error("Error fetching user:", err.message);
        if (err.kind === 'ObjectId') return res.status(404).json({ msg: 'User not found' });
        res.status(500).send('Server Error');
    }
});



// Create Post (Protected Route)
// Create Post (Protected Route)
app.post('/api/posts', auth, (req, res) => {
    upload.fields([{ name: 'image', maxCount: 1 }, { name: 'attachment', maxCount: 1 }, { name: 'avatar', maxCount: 1 }])(req, res, async (err) => {
        if (err) {
            return res.status(400).json({ msg: err });
        }

        try {
            const { title, content, category, videoUrl, type } = req.body;

            let attachment = '';
            let image = '';

            if (req.files) {
                if (req.files['attachment']) {
                    attachment = `/uploads/${req.files['attachment'][0].filename}`;
                }
                if (req.files['image']) {
                    image = `/uploads/${req.files['image'][0].filename}`;
                }
                // Legacy support (avatar was used for attachment in previous implementation)
                if (req.files['avatar'] && !attachment) {
                    attachment = `/uploads/${req.files['avatar'][0].filename}`;
                }
            }

            // Create new post
            const newPost = new Post({
                user: req.user.id,
                username: req.user.username,
                title,
                content,
                category: category || 'General',
                tag: category || 'General', // Sync tag
                videoUrl,
                attachment,
                image,
                type: type || 'quick'
            });

            const post = await newPost.save();
            res.json(post);
        } catch (err) {
            console.error(err.message);
            res.status(500).send('Server Error');
        }
    });
});


// Like/Unlike Post
app.put('/api/posts/:id/like', auth, async (req, res) => {
    try {
        const post = await Post.findById(req.params.id);
        if (!post) return res.status(404).json({ msg: 'Post not found' });

        // Check if post has already been liked
        if (post.likes.some(like => like.toString() === req.user.id)) {
            // Unlike
            post.likes = post.likes.filter(id => id.toString() !== req.user.id);
        } else {
            // Like
            post.likes.unshift(req.user.id);
        }

        await post.save();
        res.json(post.likes);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// Add Comment
app.post('/api/posts/:id/comment', auth, async (req, res) => {
    try {
        const post = await Post.findById(req.params.id);
        if (!post) return res.status(404).json({ msg: 'Post not found' });

        const newComment = {
            user: req.user.id,
            username: req.user.username,
            text: req.body.text
        };

        post.comments.unshift(newComment);
        await post.save();
        res.json(post.comments);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// Get All Posts
app.get('/api/posts', async (req, res) => {
    console.log('GET /api/posts hit');
    try {
        const posts = await Post.find()
            .sort({ createdAt: -1 })
            .populate('user', 'username profilePicture')
            .populate('comments.user', 'username profilePicture');
        res.json(posts);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// Seeding Route (Protected by simple query param or removed after use)
app.get('/api/seed_db', async (req, res) => {
    try {
        console.log('Starting remote seeding...');
        await seedData();
        res.send('Seeding Complete! Database populated.');
    } catch (err) {
        console.error('Seeding Failed:', err);
        res.status(500).send('Seeding Failed: ' + err.message);
    }
});

// Health Check
app.get('/ping', (req, res) => {
    console.log('Ping received');
    res.send('pong');
});

// Global Error Handler
app.use((err, req, res, next) => {
    console.error('Unhandled Error:', err);
    res.status(500).send('Something broke!');
});

// Start Server
app.listen(PORT, () => console.log(`Server started on port ${PORT}`));
