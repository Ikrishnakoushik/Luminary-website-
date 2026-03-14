require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const path = require('path');
const fs = require('fs'); // Import fs
const User = require('./models/User');
const Post = require('./models/Post');
const Message = require('./models/Message');
const Book = require('./models/Book'); // Added Book model

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'your_jwt_secret_key_here';
const ADMIN_EMAIL = process.env.ADMIN_EMAIL;
const ADMIN_SECRET_KEY = process.env.ADMIN_SECRET_KEY || 'Xy7@$Lp9!vQ2#mK8*jN5^hB4&cW1%zR3';
const nodemailer = require('nodemailer');
const { Resend } = require('resend');
let resend;
if (process.env.RESEND_API_KEY) {
    resend = new Resend(process.env.RESEND_API_KEY);
} else {
    resend = null;
}
const crypto = require('crypto');
const Razorpay = require('razorpay');

const razorpayInstance = new Razorpay({
    key_id: process.env.RAZORPAY_KEY_ID || 'rzp_test_placeholder',
    key_secret: process.env.RAZORPAY_KEY_SECRET || 'secret_placeholder'
});

// Nodemailer Transporter (Configure with your email service)
const transporter = nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 465,
    secure: true, // Use SSL
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
    },
    family: 4, // Force IPv4 to prevent ENETUNREACH errors
    connectionTimeout: 10000, // 10 seconds timeout
    greetingTimeout: 5000,
    socketTimeout: 10000
});

// Verify Transporter Connection
if (!resend) {
    transporter.verify(function (error, success) {
        if (error) {
            console.error('[Nodemailer Error] Connection failed:', error);
        } else {
            console.log('[Nodemailer] Server is ready to take our messages');
        }
    });
}

// Universal Email Sender
async function sendEmail({ to, subject, text }) {
    if (resend) {
        try {
            const data = await resend.emails.send({
                from: process.env.RESEND_FROM_EMAIL || 'onboarding@resend.dev',
                to,
                subject,
                html: `<p>${text.replace(/\\n/g, '<br>')}</p>`
            });
            console.log('[DEBUG] Resend email sent successfully:', data);
            return data;
        } catch (error) {
            console.error('[DEBUG] Resend Error:', error);
            throw error;
        }
    } else {
        const mailOptions = {
            from: process.env.EMAIL_USER || 'no-reply@spectra.com',
            to,
            subject,
            text
        };
        try {
            const info = await transporter.sendMail(mailOptions);
            console.log('[DEBUG] Nodemailer email sent successfully: ' + info.response);
            return info;
        } catch (error) {
            console.error('[DEBUG] Nodemailer Error:', error);
            throw error;
        }
    }
}

// Ensure uploads directory exists
const uploadDir = process.env.VERCEL ? '/tmp/uploads' : path.join(__dirname, 'public/uploads');
if (!fs.existsSync(uploadDir)) {
    try {
        fs.mkdirSync(uploadDir, { recursive: true });
    } catch (err) {
        console.error("Could not create upload directory:", err);
    }
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
app.use(express.static(path.join(__dirname, 'public'), {
    extensions: ['html'],
    setHeaders: function (res, path) {
        if (path.indexOf('.html') !== -1 || path.indexOf('.js') !== -1) {
            res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
            res.setHeader('Pragma', 'no-cache');
            res.setHeader('Expires', '0');
        }
    }
}));
const auth = (req, res, next) => {
    const token = req.header('x-auth-token');
    if (!token) return res.status(401).json({ msg: 'No token, authorization denied' });

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded.user;
        next();
    } catch (err) {
        console.log(`[DEBUG AUTH] Token validation failed. Error: ${err.message}. Token snippets: prefix(${token.substring(0, 10)}) length(${token.length}) secretLength(${JWT_SECRET.length})`);
        res.status(401).json({ msg: 'Token is not valid' });
    }
};

// Strict Admin Authentication Middleware
const adminAuth = async (req, res, next) => {
    const token = req.header('x-auth-token');
    if (!token) return res.status(401).json({ msg: 'No token, authorization denied' });

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = decoded.user;
        
        // Double-verify against the database to guarantee role hasn't changed
        const dbUser = await User.findById(req.user.id);
        if (!dbUser || dbUser.role !== 'admin') {
            console.log(`[SECURITY ALERT] Non-admin user ${req.user.id} attempted to access an admin route.`);
            return res.status(403).json({ msg: 'Access Denied: Requires Admin Privileges' });
        }
        
        next();
    } catch (err) {
        res.status(401).json({ msg: 'Token is not valid' });
    }
};

// 2FA Gateway Double-Lock Middleware
const gatewayAuth = async (req, res, next) => {
    // This expects a second, short-lived token generated ONLY when the hard credentials are submitting on the frontend
    const gatewayToken = req.header('x-gateway-token');
    if (!gatewayToken) return res.status(401).json({ msg: 'Gateway Access Denied' });

    try {
        const decoded = jwt.verify(gatewayToken, JWT_SECRET);
        if (!decoded.gatewayVerified) {
            return res.status(401).json({ msg: 'Invalid Gateway Signature' });
        }
        next();
    } catch (err) {
        res.status(401).json({ msg: 'Gateway Session Expired - Please re-authenticate' });
    }
};

// Database Connection
const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/everything_spread';
let isConnected = false;

const connectDB = async () => {
    if (isConnected) {
        return;
    }
    try {
        console.error('[Startup] Checking Mongo connection...');
        const db = await mongoose.connect(MONGO_URI, {
            serverSelectionTimeoutMS: 5000,
            socketTimeoutMS: 45000,
        });
        isConnected = db.connections[0].readyState;
        console.error('[Startup] MongoDB Connected');
    } catch (err) {
        console.error('[Startup] MongoDB Error:', err);
    }
};

// Connect immediately to start the process
connectDB();

// Middleware to ensure DB is connected before handling API requests
app.use('/api', async (req, res, next) => {
    await connectDB();
    next();
});

// Dynamic Sitemap Generation
app.get('/sitemap.xml', async (req, res) => {
    try {
        await connectDB();
        const HOST = 'https://vylithra.in';
        
        // Let's create the XML structure
        let xml = '<?xml version="1.0" encoding="UTF-8"?>\n';
        xml += '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n';

        // 1. Static Core Pages
        const staticPages = [
            '/',
            '/auth',
            '/main',
            '/studio',
            '/settings',
            '/community',
            '/books',
            '/creator-kit',
            '/publish',
            '/publish-book',
            '/documentation',
            '/legal',
            '/messages',
            '/profile'
        ];

        staticPages.forEach(page => {
            xml += `  <url>\n    <loc>${HOST}${page}</loc>\n    <changefreq>daily</changefreq>\n    <priority>0.8</priority>\n  </url>\n`;
        });

        // 2. Dynamic Books Pages
        const books = await Book.find({ status: 'published' }).select('_id updatedAt');
        books.forEach(book => {
            xml += `  <url>\n    <loc>${HOST}/checkout?bookId=${book._id}</loc>\n    <lastmod>${(book.updatedAt || new Date()).toISOString()}</lastmod>\n    <changefreq>weekly</changefreq>\n    <priority>0.9</priority>\n  </url>\n`;
        });

        // 3. Close the XML tag
        xml += '</urlset>';

        // Send the response with correct Content-Type format
        res.header('Content-Type', 'application/xml');
        res.send(xml);
    } catch (error) {
        console.error('[Sitemap] Failed to generate sitemap:', error);
        res.status(500).end();
    }
});

// Routes
const multer = require('multer');

// Configure Multer Storage
const storage = multer.diskStorage({
    destination: process.env.VERCEL ? '/tmp/uploads/' : './public/uploads/',
    filename: function (req, file, cb) {
        cb(null, 'avatar-' + Date.now() + path.extname(file.originalname));
    }
});

const upload = multer({
    storage: storage,
    limits: {
        fileSize: 5000000, // 5MB limit for files
        fieldSize: 25 * 1024 * 1024 // 25MB limit for text fields (allows full book manuscripts)
    },
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
            return res.status(400).json({ msg: 'Email already registered' });
        }

        // Check if username exists
        let existingUsername = await User.findOne({ username });
        if (existingUsername) {
            return res.status(400).json({ msg: 'Username already taken' });
        }

        // Hash password
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        // Validate role - STRICTLY explicitly prevent 'admin' injection
        let validRoles = ['publisher', 'reader'];
        let userRole = validRoles.includes(role) ? role : 'reader';

        // --- PRODUCTION SECURITY: Auto-provision Master Admin ---
        if (ADMIN_EMAIL && email.toLowerCase() === ADMIN_EMAIL.toLowerCase()) {
            userRole = 'admin';
            console.log(`[SECURITY] Auto-provisioned master admin role for ${email}`);
        }

        // Generate 6-digit OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        console.log(`[DEBUG] Generated OTP for ${email}: ${otp}`); // Log OTP for testing



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
        try {
            await sendEmail({
                to: user.email,
                subject: 'Spectra - Verify Your Email',
                text: `Welcome to Spectra! Please verify your email using this OTP: ${otp}\n\nIt expires in 10 minutes.`
            });
        } catch (emailError) {
            console.error('[Warning] Email sending failed, but continuing registration:', emailError);
            // Non-blocking in dev mode since we log OTP
        }
        res.status(201).json({ msg: 'User registered. Please verify your email.', email });
    } catch (err) {
        console.error(err);
        res.status(500).json({ msg: 'Server error' });
    }
});

// Verify Email Route
app.post('/api/verify-email', async (req, res) => {
    const { email, otp } = req.body;
    try {
        const user = await User.findOne({ email });
        if (!user) return res.status(400).json({ msg: 'User not found' });

        if (user.isVerified) return res.status(400).json({ msg: 'User already verified' });

        if (user.verificationOtp !== otp) return res.status(400).json({ msg: 'Invalid OTP' });

        user.isVerified = true;
        user.verificationOtp = undefined;
        await user.save();

        // Login automatically
        const payload = { user: { id: user.id, role: user.role } };
        jwt.sign(payload, JWT_SECRET, { expiresIn: '30d' }, (err, token) => {
            if (err) throw err;
            res.json({ token, username: user.username, role: user.role });
        });

    } catch (err) {
        console.error(err);
        res.status(500).json({ msg: 'Server error' });
    }
});

// Forgot Password (Send OTP)
app.post('/api/auth/forgot-password', async (req, res) => {
    const { email } = req.body;
    try {
        const user = await User.findOne({ email });
        if (!user) return res.status(404).json({ msg: 'User not found' });

        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        user.resetPasswordOtp = otp;
        user.resetPasswordExpires = Date.now() + 10 * 60 * 1000; // 10 mins
        await user.save();

        try {
            await sendEmail({
                to: email,
                subject: 'Vylithra - Password Reset OTP',
                text: `Your OTP for password reset is: ${otp}\n\nIt expires in 10 minutes.`
            });
            res.json({ msg: 'OTP sent to email', email: user.email });
        } catch (error) {
            console.error('[DEBUG] Email Error in Forgot Password:', error);
            return res.status(500).json({ msg: 'Email failed: ' + error.message });
        }

    } catch (err) {
        console.error('[DEBUG] Server Error in Forgot Password:', err);
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

        // Check if user is verified
        if (user.isVerified === false) {
            return res.status(403).json({ msg: 'Please verify your email before logging in.', requiresVerification: true });
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
            { expiresIn: '30d' },
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

// Get Profile Info
app.get('/api/users/profile', auth, async (req, res) => {
    try {
        const user = await User.findById(req.user.id).select('-password');
        if (!user) {
            return res.status(404).json({ msg: 'User not found' });
        }
        res.json(user);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// Update Profile Info
app.put('/api/users/profile', auth, async (req, res) => {
    try {
        const { displayName, bio, username, email, socials } = req.body;

        // Build update object
        const updateFields = {};
        if (displayName) updateFields.displayName = displayName;
        if (bio) updateFields.bio = bio;
        if (username) updateFields.username = username;
        if (email) updateFields.email = email;
        if (socials) updateFields.socials = socials;

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

// Get Top Users (Spreaders) - for Sidebar
app.get('/api/users/top', async (req, res) => {
    try {
        // Fetch 5 random users with 'publisher' role
        const users = await User.aggregate([
            { $match: { role: 'publisher' } },
            { $sample: { size: 5 } },
            { $project: { password: 0, email: 0, verificationOtp: 0, resetPasswordOtp: 0 } }
        ]);

        // If not enough publishers, just get any users
        if (users.length === 0) {
            const anyUsers = await User.find().select('-password -email').limit(5);
            return res.json(anyUsers);
        }

        res.json(users);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});
// Toggle Connection (Follow/Unfollow)
app.post('/api/users/connect/:id', auth, async (req, res) => {
    try {
        if (req.user.id === req.params.id) {
            return res.status(400).json({ msg: 'You cannot connect with yourself' });
        }

        const targetUser = await User.findById(req.params.id);
        if (!targetUser) return res.status(404).json({ msg: 'User not found' });

        const currentUser = await User.findById(req.user.id);

        // Toggle connection
        const connectionIndex = currentUser.connections.indexOf(req.params.id);
        if (connectionIndex !== -1) {
            // Unfollow
            currentUser.connections.splice(connectionIndex, 1);
        } else {
            // Follow
            currentUser.connections.unshift(req.params.id);
        }

        await currentUser.save();
        res.json(currentUser.connections);
    } catch (err) {
        console.error(err.message);
        if (err.kind === 'ObjectId') {
            return res.status(404).json({ msg: 'User not found' });
        }
        res.status(500).send('Server Error');
    }
});

// Get Current User's Connections List
app.get('/api/users/connections', auth, async (req, res) => {
    try {
        const user = await User.findById(req.user.id)
            .populate('connections', 'username displayName profilePicture role bio projects');

        if (!user) return res.status(404).json({ msg: 'User not found' });

        res.json(user.connections);
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

// Delete Post
app.delete('/api/posts/:id', auth, async (req, res) => {
    try {
        const post = await Post.findById(req.params.id);

        if (!post) {
            return res.status(404).json({ msg: 'Post not found' });
        }

        // Check user
        if (post.user.toString() !== req.user.id) {
            return res.status(401).json({ msg: 'User not authorized' });
        }

        await post.deleteOne();

        res.json({ msg: 'Post removed' });
    } catch (err) {
        console.error(err.message);
        if (err.kind === 'ObjectId') {
            return res.status(404).json({ msg: 'Post not found' });
        }
        res.status(500).send('Server Error');
    }
});

// Get All Posts (with optional filtering)
app.get('/api/posts', async (req, res) => {
    console.error(`[API] GET /api/posts request received with query:`, req.query);
    try {
        const query = {};
        if (req.query.user) {
            query.user = req.query.user;
        }
        if (req.query.likedBy) {
            query.likes = req.query.likedBy;
        }

        const limit = parseInt(req.query.limit) || 20;

        const posts = await Post.find(query)
            .sort({ createdAt: -1 })
            .limit(limit)
            .populate('user', 'username profilePicture')
            .populate('comments.user', 'username profilePicture');

        res.json(posts);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
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

// --- MESSAGES API ---

// Get all recent conversations for the current user
app.get('/api/messages/conversations', auth, async (req, res) => {
    try {
        const userId = req.user.id;

        // Find all messages where user is sender or receiver
        const messages = await Message.find({
            $or: [{ sender: userId }, { receiver: userId }]
        })
            .sort({ createdAt: -1 })
            .populate('sender', 'username profilePicture')
            .populate('receiver', 'username profilePicture');

        // Extract unique conversations
        const convosMap = new Map();

        messages.forEach(msg => {
            const isSentByMe = msg.sender._id.toString() === userId;
            const otherUser = isSentByMe ? msg.receiver : msg.sender;

            if (!otherUser) return; // In case user was deleted

            const otherUserId = otherUser._id.toString();

            if (!convosMap.has(otherUserId)) {
                convosMap.set(otherUserId, {
                    user: otherUser,
                    lastMessage: msg.content,
                    timestamp: msg.createdAt,
                    unread: !isSentByMe && msg.unread
                });
            }
        });

        const convos = Array.from(convosMap.values());
        res.json(convos);

    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// Get messages with a specific user
app.get('/api/messages/:userId', auth, async (req, res) => {
    try {
        const userId = req.user.id;
        const otherUserId = req.params.userId;

        const messages = await Message.find({
            $or: [
                { sender: userId, receiver: otherUserId },
                { sender: otherUserId, receiver: userId }
            ]
        }).sort({ createdAt: 1 });

        // Mark as read if receiving them
        await Message.updateMany(
            { sender: otherUserId, receiver: userId, unread: true },
            { $set: { unread: false } }
        );

        res.json(messages);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// Global Search
app.get('/api/search', async (req, res) => {
    try {
        const query = req.query.q;
        if (!query) {
            return res.json({ users: [], posts: [], books: [] });
        }

        const users = await User.find({
            $or: [
                { username: { $regex: query, $options: 'i' } },
                { displayName: { $regex: query, $options: 'i' } }
            ]
        }).select('username displayName profilePicture role').limit(5);

        const posts = await Post.find({
            $or: [
                { title: { $regex: query, $options: 'i' } },
                { author: { $in: users.map(u => u._id) } }
            ]
        }).populate('author', 'username displayName').limit(5);

        const books = await Book.find({
            $or: [
                { title: { $regex: query, $options: 'i' } }
            ]
        }).populate('author', 'username displayName').limit(5);

        res.json({ users, posts, books });
    } catch (err) {
        console.error('Search error:', err);
        res.status(500).json({ msg: 'Server Error' });
    }
});

// ==========================================
// BOOKS ROUTES
// ==========================================

// Get All Books
app.get('/api/books', async (req, res) => {
    try {
        const books = await Book.find().populate('author', 'username displayName profilePicture').sort({ createdAt: -1 });

        let currentUser = null;
        const token = req.header('x-auth-token');
        if (token) {
            try {
                const decoded = jwt.verify(token, JWT_SECRET);
                currentUser = await User.findById(decoded.user.id);
            } catch (err) { }
        }

        const filteredBooks = books.filter(book => {
            if (book.isPublished !== false) return true; // Show if published or undefined
            if (!currentUser) return false;
            // Show unpublished only to author or someone who purchased it
            if (book.author._id.toString() === currentUser._id.toString()) return true;
            if (currentUser.purchasedBooks.includes(book._id)) return true;
            return false;
        });

        res.json(filteredBooks);
    } catch (err) {
        console.error('Error fetching books:', err);
        res.status(500).json({ msg: 'Server Error' });
    }
});

// Get Single Book
app.get('/api/books/:id', auth, async (req, res) => {
    try {
        const book = await Book.findById(req.params.id).populate('author', 'username displayName profilePicture');
        if (!book) return res.status(404).json({ msg: 'Book not found' });

        // Strip out content if not purchased and not the author
        const user = await User.findById(req.user.id);
        const isAuthor = book.author._id.toString() === req.user.id;
        const hasPurchased = user.purchasedBooks.includes(book._id);

        if (book.isPublished === false && !isAuthor && !hasPurchased) {
            return res.status(404).json({ msg: 'Book not found or unpublished' });
        }

        if (!isAuthor && !hasPurchased && book.price > 0) {
            const restrictedBook = book.toObject();
            restrictedBook.content = "Please purchase the book to read the full content.";
            return res.json(restrictedBook);
        }

        res.json(book);
    } catch (err) {
        console.error('Error fetching book:', err);
        res.status(500).json({ msg: 'Server Error' });
    }
});

// Publish a Book
app.post('/api/books', auth, (req, res) => {
    upload.single('coverImageFile')(req, res, async (err) => {
        if (err) {
            console.error("Multer error in book publish:", err);
            return res.status(400).json({ msg: err.message || err });
        }
        try {
            const { title, description, price, coverImage, content, penName, category } = req.body;

            // Check if publisher
            if (req.user.role !== 'publisher') {
                return res.status(403).json({ msg: 'Only publishers can create books' });
            }

            let finalCoverImage = coverImage || '';
            if (req.file) {
                finalCoverImage = `/uploads/${req.file.filename}`;
            }

            const newBook = new Book({
                title,
                description,
                price: price || 0,
                coverImage: finalCoverImage,
                content,
                penName: penName || '',
                category: category || 'General',
                author: req.user.id
            });

            const savedBook = await newBook.save();

            // Add to author's published books
            await User.findByIdAndUpdate(req.user.id, { $push: { publishedBooks: savedBook._id } });

            res.json(savedBook);
        } catch (err) {
            console.error('Error creating book:', err);
            res.status(500).json({ msg: 'Server Error' });
        }
    });
});

// Update a Book
app.put('/api/books/:id', auth, (req, res) => {
    upload.single('coverImageFile')(req, res, async (err) => {
        if (err) {
            console.error("Multer error in book update:", err);
            return res.status(400).json({ msg: err.message || err });
        }
        try {
            const { title, description, price, coverImage, content, penName, category } = req.body;

            let book = await Book.findById(req.params.id);
            if (!book) return res.status(404).json({ msg: 'Book not found' });

            // Ensure user is author
            if (book.author.toString() !== req.user.id) {
                return res.status(401).json({ msg: 'Not authorized to edit this book' });
            }

            let finalCoverImage = coverImage;
            if (req.file) {
                finalCoverImage = `/uploads/${req.file.filename}`;
            }

            // Update fields
            if (title) book.title = title;
            if (description) book.description = description;
            if (price !== undefined) book.price = price;
            if (finalCoverImage !== undefined) book.coverImage = finalCoverImage;
            if (content) book.content = content;
            if (penName !== undefined) book.penName = penName;
            if (category) book.category = category;

            await book.save();
            res.json(book);
        } catch (err) {
            console.error('Error updating book:', err);
            res.status(500).json({ msg: 'Server Error' });
        }
    });
});

// Toggle Publish Status of a Book
app.put('/api/books/:id/unpublish', auth, async (req, res) => {
    try {
        let book = await Book.findById(req.params.id);
        if (!book) return res.status(404).json({ msg: 'Book not found' });

        if (book.author.toString() !== req.user.id) {
            return res.status(401).json({ msg: 'Not authorized to toggle publish status' });
        }

        // Default is true if undefined, so toggle the opposite
        book.isPublished = book.isPublished === false ? true : false;
        await book.save();
        res.json({ msg: book.isPublished ? 'Book published successfully!' : 'Book unpublished successfully', book });
    } catch (err) {
        console.error('Error unpublishing book:', err);
        res.status(500).json({ msg: 'Server Error' });
    }
});

// Delete a Book (Hard delete + refund)
app.delete('/api/books/:id', auth, async (req, res) => {
    try {
        const book = await Book.findById(req.params.id);
        if (!book) return res.status(404).json({ msg: 'Book not found' });

        // Ensure user is author
        if (book.author.toString() !== req.user.id) {
            return res.status(401).json({ msg: 'Not authorized to delete this book' });
        }

        // Calculate refunds
        const purchasers = await User.find({ purchasedBooks: book._id });
        const refundAmount = (book.price || 0) * purchasers.length;

        // Verify author has enough balance
        const author = await User.findById(req.user.id);
        if (author.balance < refundAmount) {
            return res.status(400).json({ msg: `Insufficient balance for refunds. Required: ₹${refundAmount}, Available: ₹${author.balance}` });
        }

        // Deduct balance from author
        if (refundAmount > 0) {
            author.balance -= refundAmount;
            await author.save();
        }

        // Remove from purchasers' libraries
        await User.updateMany(
            { purchasedBooks: book._id },
            { $pull: { purchasedBooks: book._id } }
        );

        await book.deleteOne();

        // Remove from author's publishedBooks array
        await User.findByIdAndUpdate(req.user.id, { $pull: { publishedBooks: req.params.id } });

        res.json({ msg: refundAmount > 0 ? `Book deleted and ₹${refundAmount} automatically refunded from your balance.` : 'Free Book completely deleted.' });
    } catch (err) {
        console.error('Error deleting book:', err);
        if (err.kind === 'ObjectId') return res.status(404).json({ msg: 'Book not found' });
        res.status(500).json({ msg: 'Server Error' });
    }
});

// Rate a Book
app.post('/api/books/:id/rate', auth, async (req, res) => {
    try {
        const { score } = req.body;

        // Validate score
        if (!score || score < 1 || score > 10) {
            return res.status(400).json({ msg: 'Please provide a valid score between 1 and 10' });
        }

        const book = await Book.findById(req.params.id);
        if (!book) {
            return res.status(404).json({ msg: 'Book not found' });
        }

        // Check if user has already rated
        const existingRating = book.ratings.find(r => r.user.toString() === req.user.id);

        if (existingRating) {
            // Update existing rating
            existingRating.score = score;
        } else {
            // Add new rating
            book.ratings.push({ user: req.user.id, score });
        }

        // Recalculate average rating
        const totalScore = book.ratings.reduce((acc, curr) => acc + curr.score, 0);
        book.averageRating = Number((totalScore / book.ratings.length).toFixed(1));

        await book.save();
        res.json({ msg: 'Rating submitted successfully', averageRating: book.averageRating });

    } catch (err) {
        console.error('Error rating book:', err);
        if (err.kind === 'ObjectId') return res.status(404).json({ msg: 'Book not found' });
        res.status(500).json({ msg: 'Server Error' });
    }
});

// Unified Purchase Intent (Razorpay Gateway)
app.post('/api/books/:id/purchase-intent', auth, async (req, res) => {
    try {
        const book = await Book.findById(req.params.id);
        if (!book) return res.status(404).json({ msg: 'Book not found' });

        const user = await User.findById(req.user.id);
        if (user.purchasedBooks.includes(book._id)) {
            return res.status(400).json({ msg: 'You have already purchased this book' });
        }

        // Create Razorpay Order
        const amountInPaise = Math.round((book.price || 0) * 100); // Razorpay expects paise (lowest denominator)
        const options = {
            amount: amountInPaise,
            currency: 'INR',
            receipt: `receipt_order_${Math.random().toString(36).substring(2, 10)}`,
            notes: {
                bookId: book._id.toString(),
                userId: req.user.id.toString(),
                publisherId: book.author.toString()
            }
        };

        const order = await razorpayInstance.orders.create(options);

        // Tell frontend to open Razorpay Modal instead of redirecting
        res.json({
            type: 'razorpay',
            order_id: order.id,
            amount: amountInPaise,
            currency: 'INR',
            key_id: process.env.RAZORPAY_KEY_ID
        });
    } catch (err) {
        console.error('Razorpay Order Error:', err);
        // Razorpay often nests the error message inside err.error.description
        const errorMsg = (err.error && err.error.description) || err.description || err.message || JSON.stringify(err);
        res.status(500).json({ msg: 'Payment Service Error: ' + errorMsg });
    }
});



// Verify Purchase after Razorpay modal completion
app.post('/api/books/verify-purchase', auth, async (req, res) => {
    try {
        const { razorpay_order_id, razorpay_payment_id, razorpay_signature, book_id } = req.body;

        // Verify the signature
        const secret = process.env.RAZORPAY_KEY_SECRET || 'secret_placeholder';
        const generated_signature = crypto
            .createHmac('sha256', secret)
            .update(razorpay_order_id + "|" + razorpay_payment_id)
            .digest('hex');

        if (generated_signature === razorpay_signature) {
            // Payment is successful and authentic
            const user = await User.findById(req.user.id);
            if (!user.purchasedBooks.includes(book_id)) {
                // Fulfill order
                user.purchasedBooks.push(book_id);
                await user.save();

                // Credit publisher's internal wallet
                const book = await Book.findById(book_id);
                if (book && book.price > 0) {
                    const publisher = await User.findById(book.author);
                    if (publisher) {
                        publisher.walletBalance = (publisher.walletBalance || 0) + book.price;
                        publisher.totalEarned = (publisher.totalEarned || 0) + book.price;
                        await publisher.save();
                    }
                }
            }
            res.json({ msg: 'Purchase verified successfully' });
        } else {
            res.status(400).json({ msg: 'Payment signature verification failed' });
        }
    } catch (err) {
        console.error('Verify Purchase Error:', err);
        res.status(500).json({ msg: 'Server Error' });
    }
});

// GET Publisher Earnings Dashboard Data
app.get('/api/publishers/earnings', auth, async (req, res) => {
    try {
        const user = await User.findById(req.user.id).select('walletBalance totalEarned withdrawalHistory role');
        if (!user || (user.role !== 'publisher' && user.role !== 'admin')) {
            return res.status(403).json({ msg: 'Access denied' });
        }
        res.json({
            walletBalance: user.walletBalance,
            totalEarned: user.totalEarned,
            withdrawalHistory: user.withdrawalHistory || []
        });
    } catch (err) {
        console.error('Error fetching earnings:', err);
        res.status(500).json({ msg: 'Server Error' });
    }
});

// POST Publisher Withdrawal Request
app.post('/api/publishers/withdraw', auth, async (req, res) => {
    try {
        const { amount, method, details } = req.body;
        if (!amount || amount <= 0) return res.status(400).json({ msg: 'Invalid withdrawal amount' });

        const user = await User.findById(req.user.id);
        if (!user || (user.role !== 'publisher' && user.role !== 'admin')) {
            return res.status(403).json({ msg: 'Access denied' });
        }

        if (user.walletBalance < amount) {
            return res.status(400).json({ msg: 'Insufficient wallet balance' });
        }

        // Deduct from wallet and log to history
        user.walletBalance -= amount;
        user.withdrawalHistory.push({
            amount: amount,
            status: 'completed',
            method: method || 'UPI',
            details: details || 'Not provided'
        });

        await user.save();
        res.json({ msg: 'Withdrawal processed instantly', walletBalance: user.walletBalance });

    } catch (err) {
        console.error('Error processing withdrawal:', err);
        res.status(500).json({ msg: 'Server Error' });
    }
});


// Upgrade user to publisher role
app.put('/api/users/upgrade-to-publisher', auth, async (req, res) => {
    try {
        const user = await User.findById(req.user.id);
        if (!user) {
            return res.status(404).json({ msg: 'User not found' });
        }

        if (user.role === 'publisher') {
            return res.status(400).json({ msg: 'User is already a publisher' });
        }

        user.role = 'publisher';
        await user.save();

        res.json({
            msg: 'Successfully upgraded to publisher account',
            user: {
                id: user._id,
                username: user.username,
                email: user.email,
                role: user.role,
                name: user.name,
                avatar: user.avatar,
                bio: user.bio,
                balance: user.balance
            }
        });
    } catch (err) {
        console.error('Upgrade Error:', err);
        res.status(500).json({ msg: 'Server Error' });
    }
});

// Downgrade user to reader role
app.put('/api/users/downgrade-to-reader', auth, async (req, res) => {
    try {
        const user = await User.findById(req.user.id);
        if (!user) {
            return res.status(404).json({ msg: 'User not found' });
        }

        if (user.role === 'reader') {
            return res.status(400).json({ msg: 'User is already a reader' });
        }

        user.role = 'reader';
        await user.save();

        res.json({
            msg: 'Successfully downgraded to reader account',
            user: {
                id: user._id,
                username: user.username,
                email: user.email,
                role: user.role,
                name: user.name,
                avatar: user.avatar,
                bio: user.bio,
                balance: user.balance
            }
        });
    } catch (err) {
        console.error('Downgrade Error:', err);
        res.status(500).json({ msg: 'Server Error' });
    }
});


// Onboard Publisher (Multi-Method Support)
app.post('/api/publisher/onboard', auth, async (req, res) => {
    try {
        const { method, handle } = req.body;
        const user = await User.findById(req.user.id);

        if (user.role !== 'publisher' && user.role !== 'admin') {
            return res.status(403).json({ msg: 'Only publishers and admins can onboard payout methods' });
        }

        if (method === 'razorpay') {
            user.preferredPaymentMethod = method;
        } else if (['paypal', 'upi', 'manual'].includes(method)) {
            user.preferredPaymentMethod = method;
            user.paymentHandle = handle || '';
        } else {
            return res.status(400).json({ msg: 'Invalid payment method' });
        }

        await user.save();
        res.json({
            msg: `Successfully connected ${method}!`,
            preferredPaymentMethod: user.preferredPaymentMethod,
            paymentHandle: user.paymentHandle
        });
    } catch (err) {
        console.error('Error onboarding publisher:', err);
        res.status(500).json({ msg: 'Server Error' });
    }
});

// Get Publisher Balance
app.get('/api/publisher/balance', auth, async (req, res) => {
    try {
        const user = await User.findById(req.user.id);
        if (user.role !== 'publisher' && user.role !== 'admin') {
            return res.status(403).json({ msg: 'Only publishers and admins can view balance' });
        }
        res.json({ balance: user.balance || 0, razorpayAccountId: user.razorpayAccountId });
    } catch (err) {
        console.error('Error fetching balance:', err);
        res.status(500).json({ msg: 'Server Error' });
    }
});

// Send a message
app.post('/api/messages/:userId', auth, async (req, res) => {
    try {
        const sender = req.user.id;
        const receiver = req.params.userId;
        const { content } = req.body;

        if (!content) {
            return res.status(400).json({ msg: 'Message content is required' });
        }

        const newMessage = new Message({
            sender,
            receiver,
            content
        });

        const savedMessage = await newMessage.save();
        res.json(savedMessage);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// --- PROJECTS API ---
// Add a project
app.post('/api/users/projects', auth, async (req, res) => {
    try {
        const { title, description, link, icon } = req.body;
        const user = await User.findById(req.user.id);

        if (!user) return res.status(404).json({ msg: 'User not found' });

        const newProject = { title, description, link, icon: icon || '🚀' };
        user.projects.unshift(newProject); // Add to beginning
        await user.save();

        res.json(user.projects);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});

// Delete a project
app.delete('/api/users/projects/:id', auth, async (req, res) => {
    try {
        const user = await User.findById(req.user.id);
        if (!user) return res.status(404).json({ msg: 'User not found' });

        // Filter out project
        user.projects = user.projects.filter(p => p._id.toString() !== req.params.id);
        await user.save();

        res.json(user.projects);
    } catch (err) {
        console.error(err.message);
        res.status(500).send('Server Error');
    }
});


// --- ADMIN PORTAL API (Strictly Protected) ---

// 1. Verify Admin Session
app.get('/api/admin/verify', adminAuth, (req, res) => {
    res.status(200).json({ msg: 'Admin Verified', user: req.user });
});

// 2.5a. 2FA Gateway Unlock Request (Send OTP)
app.post('/api/admin/gateway-request', adminAuth, async (req, res) => {
    try {
        const { email, secretKey } = req.body;
        
        // Strict verification against environment variables
        if (!ADMIN_EMAIL || !ADMIN_SECRET_KEY || 
            email.toLowerCase() !== ADMIN_EMAIL.toLowerCase() || 
            secretKey !== ADMIN_SECRET_KEY) {
            console.log(`[SECURITY ALERT] Failed gateway challenge for user ${req.user.id}`);
            return res.status(401).json({ msg: 'Invalid Master Credentials' });
        }
        
        // Generate a 6-digit OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        
        // Save to User document for stateless verification
        const user = await User.findById(req.user.id);
        if(!user) return res.status(404).json({ msg: 'User not found' });
        
        user.adminGatewayOtp = otp;
        user.adminGatewayOtpExpires = Date.now() + 5 * 60 * 1000; // 5 mins
        await user.save();
        
        // Email the OTP to the master email securely
        // We do not await this, we let it process in the background. Or we can await to ensure delivery.
        try {
            await sendEmail(
                ADMIN_EMAIL, 
                "Strict Admin Security Alert: Gateway OTP", 
                `Someone successfully supplied the Master Credentials to the Vylithra backend.\nIf this was you, here is your 6-digit unlock code:\n\n${otp}\n\nThis code expires in 5 minutes.\nIf you did not request this, CHANGE YOUR MASTER SECRET KEY IMMEDIATELY from the Vercel dashboard.`
            );
        } catch (emailErr) {
            console.error('[SECURITY ALERT] Failed to send OTP email', emailErr);
            // We tell the user it sent, but log the error
        }

        res.json({ msg: 'OTP sent to Master Email. Check your inbox.' });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// 2.5b. 2FA Gateway Verification (Check OTP)
app.post('/api/admin/gateway-verify', adminAuth, async (req, res) => {
    try {
        const { otp } = req.body;
        
        const user = await User.findById(req.user.id);
        if(!user) return res.status(401).json({ msg: 'Invalid Session' });
        
        if (!user.adminGatewayOtp || !user.adminGatewayOtpExpires) {
            return res.status(400).json({ msg: 'No OTP requested or session expired. Restart Gateway.' });
        }
        
        if (Date.now() > user.adminGatewayOtpExpires) {
            user.adminGatewayOtp = null;
            user.adminGatewayOtpExpires = null;
            await user.save();
            return res.status(400).json({ msg: 'OTP has expired.' });
        }
        
        if (user.adminGatewayOtp !== otp.trim()) {
            return res.status(401).json({ msg: 'Invalid OTP.' });
        }
        
        // Success! Clear OTP
        user.adminGatewayOtp = null;
        user.adminGatewayOtpExpires = null;
        await user.save();
        
        // Generate a fast-expiring (1 hour) Gateway Ticket
        const payload = {
            gatewayVerified: true,
            adminId: req.user.id
        };
        
        jwt.sign(payload, JWT_SECRET, { expiresIn: '1h' }, (err, token) => {
            if (err) throw err;
            res.json({ token, msg: 'Gateway Unlocked' });
        });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// 3. Get Platform Stats
app.get('/api/admin/stats', adminAuth, gatewayAuth, async (req, res) => {
    try {
        const totalUsers = await User.countDocuments();
        const totalBooks = await Book.countDocuments();
        
        // Sum total earnings across all publishers as \"Platform Revenue\"
        const users = await User.find();
        let totalRevenue = 0;
        users.forEach(u => {
            totalRevenue += (u.totalEarned || 0);
        });

        res.json({ totalUsers, totalBooks, totalRevenue });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// 4. User Management (Get All)
app.get('/api/admin/users', adminAuth, gatewayAuth, async (req, res) => {
    try {
        const users = await User.find().select('-password').sort({ createdAt: -1 });
        res.json(users);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// 5. User Management (Update Role)
app.put('/api/admin/users/:id/role', adminAuth, gatewayAuth, async (req, res) => {
    try {
        const { role } = req.body;
        if (!['reader', 'publisher', 'admin'].includes(role)) {
            return res.status(400).json({ msg: 'Invalid role' });
        }
        
        const user = await User.findById(req.params.id);
        if (!user) return res.status(404).json({ msg: 'User not found' });
        
        user.role = role;
        await user.save();
        
        res.json({ msg: 'User role updated', user });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// 6. User Management (Delete User)
app.delete('/api/admin/users/:id', adminAuth, gatewayAuth, async (req, res) => {
    try {
        await User.findByIdAndDelete(req.params.id);
        res.json({ msg: 'User deleted' });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// 7. Content Management (Get All Books)
app.get('/api/admin/books', adminAuth, gatewayAuth, async (req, res) => {
    try {
        const books = await Book.find().populate('author', 'username email').sort({ createdAt: -1 });
        res.json(books);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// 8. Content Management (Toggle Book Status)
app.put('/api/admin/books/:id/status', adminAuth, gatewayAuth, async (req, res) => {
    try {
        const { status } = req.body; // 'published' or 'draft'
        const book = await Book.findById(req.params.id);
        if (!book) return res.status(404).json({ msg: 'Book not found' });
        
        book.status = status;
        await book.save();
        
        res.json({ msg: 'Book status updated', book });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// 9. Content Management (Delete Book)
app.delete('/api/admin/books/:id', adminAuth, gatewayAuth, async (req, res) => {
    try {
        await Book.findByIdAndDelete(req.params.id);
        res.json({ msg: 'Book deleted' });
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// 10. Financial Oversight (Get Withdrawals/Transactions)
app.get('/api/admin/transactions', adminAuth, gatewayAuth, async (req, res) => {
    try {
        // Collect all withdrawal histories from all users
        const users = await User.find({ 'withdrawalHistory.0': { $exists: true } }).select('username email withdrawalHistory');
        
        let allTransactions = [];
        users.forEach(u => {
            u.withdrawalHistory.forEach(w => {
                allTransactions.push({
                    userId: u._id,
                    username: u.username,
                    email: u.email,
                    amount: w.amount,
                    date: w.date,
                    status: w.status,
                    method: w.method,
                    details: w.details
                });
            });
        });
        
        // Sort by date newest first
        allTransactions.sort((a, b) => new Date(b.date) - new Date(a.date));
        
        res.json(allTransactions);
    } catch (err) {
        console.error(err);
        res.status(500).send('Server Error');
    }
});

// Start Server
if (process.env.NODE_ENV !== 'production') {
    app.listen(PORT, () => console.error(`[Startup] Server started on port ${PORT} `));
}
module.exports = app;
