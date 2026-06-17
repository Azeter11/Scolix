require('dotenv').config()

const express = require('express')
const cors = require('cors')

const app = express()

app.use(cors())
app.use(express.json())

// ROOT
app.get("/", (req, res) => {

    res.send("SCOLIX API RUNNING")

})

// CHAT AI
app.post("/chat", (req, res) => {

    const message = req.body.message

    res.json({

        reply:
            "AI menerima: " + message

    })

})

// REQUEST OTP
const nodemailer =
    require('nodemailer')

const otpGenerator =
    require('otp-generator')

const otpStore = {}
const transporter =
    nodemailer.createTransport({

        host: "smtp.gmail.com",

        port: 587,

        secure: false,

        auth: {

            user:
                process.env.EMAIL_USER,

            pass:
                process.env.EMAIL_PASS

        },

        tls: {
            rejectUnauthorized: false
        }

    })

app.post(
    "/request-otp",
    async (req, res) => {

        try {
            const email =
                req.body.email

            const otp =
                otpGenerator.generate(
                    5,
                    {
                        upperCaseAlphabets: false,
                        specialChars: false,
                        lowerCaseAlphabets: false,
                        digits: true
                    }
                )

            otpStore[email] = {

                otp,

                expire:
                    Date.now() + 300000

            }
            console.log(
                "OTP:",
                otp
            )

            await transporter
                .sendMail({

                    from:
                        process.env.EMAIL_USER,

                    to: email,

                    subject:
                        "Kode OTP SCOLIX",

                    html: `

<h2>SCOLIX OTP</h2>

<p>Kode OTP:</p>

<h1>${otp}</h1>

<p>Berlaku 5 menit</p>

`

                })

            res.json({

                success: true,

                message:
                    "OTP terkirim"

            })

        } catch (e) {

            console.log(
                "OTP ERROR:",
                e
            )

            res.status(500)
                .json({

                    success: false

                })

        }

    })

app.post(
    "/verify-otp",
    (req, res) => {

        const email =
            req.body.email

        const code =
            req.body.code

        const data =
            otpStore[email]

        if (!data) {

            return res
                .status(400)
                .json({
                    success: false
                })

        }

        if (
            Date.now()
            >
            data.expire
        ) {

            delete otpStore[email]

            return res
                .status(400)
                .json({
                    success: false
                })

        }

        if (
            data.otp !== code
        ) {

            return res
                .status(400)
                .json({
                    success: false
                })

        }

        delete otpStore[email]

        res.json({
            success: true
        })

    })
app.get('/test-mail', async (req, res) => {
    try {
        await transporter.sendMail({
            from: process.env.EMAIL_USER,
            to: process.env.EMAIL_USER,
            subject: 'TEST SCOLIX',
            html: '<h1>Email test berhasil</h1>',
        });

        res.send('EMAIL BERHASIL');
    } catch (e) {
        console.log(e);
        res.status(500).send(e.toString());
    }
});
const PORT =
    process.env.PORT || 3000

app.listen(PORT, () => {

    console.log(
        `RUNNING ${PORT}`
    )



})