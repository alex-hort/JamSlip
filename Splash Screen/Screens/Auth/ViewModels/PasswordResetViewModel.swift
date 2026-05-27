//
//  PasswordResetViewModel.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 10/01/26.
//

import Combine
import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class PasswordResetViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var otpCode: String = ""
    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var successMessage: String = ""
    @Published var showError: Bool = false
    @Published var showSuccess: Bool = false
    
    // OTP generado (en producción esto debe estar en el backend)
    private var generatedOTP: String = ""
    private var otpEmail: String = ""
    
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()
    
    // MARK: - 1️⃣ Enviar Código OTP por Email
    func sendOTPCode() async -> Bool {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email"
            showError = true
            return false
        }

        isLoading = true

        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)

            isLoading = false
            successMessage = """
            Te hemos enviado un correo para restablecer tu contraseña.
            Revisa spam también.
            """
            showSuccess = true
            return true

        } catch {
            errorMessage = error.localizedDescription
            showError = true
            isLoading = false
            return false
        }
    }
    
    // MARK: - 2️⃣ Verificar Código OTP
    func verifyOTP() async -> Bool {
        guard otpCode.count == 6 else {
            errorMessage = "Please enter the 6-digit code"
            showError = true
            return false
        }
        
        // Verificar contra Firestore
        do {
            let doc = try await firestore
                .collection("password_resets")
                .document(otpEmail)
                .getDocument()
            
            guard let data = doc.data(),
                  let savedCode = data["code"] as? String,
                  let expiresAt = data["expiresAt"] as? Timestamp else {
                errorMessage = "Verification code not found"
                showError = true
                return false
            }
            
            // Verificar si expiró
            if expiresAt.dateValue() < Date() {
                errorMessage = "Verification code has expired"
                showError = true
                return false
            }
            
            // Verificar código
            guard otpCode == savedCode else {
                errorMessage = "Invalid verification code"
                showError = true
                return false
            }
            
            print("✅ Código verificado correctamente")
            return true
            
        } catch {
            errorMessage = "Error verifying code: \(error.localizedDescription)"
            showError = true
            return false
        }
    }
    
    // MARK: - 3️⃣ Restablecer Contraseña
    func resetPassword() async -> Bool {
        guard !newPassword.isEmpty else {
            errorMessage = "Please enter a new password"
            showError = true
            return false
        }
        
        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            showError = true
            return false
        }
        
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don't match"
            showError = true
            return false
        }
        
        isLoading = true
        
        do {
            // Obtener el usuario actual que está logueado
            guard let currentUser = auth.currentUser else {
                // Si no hay sesión activa, enviar email de reset
                try await auth.sendPasswordReset(withEmail: otpEmail)
                
                isLoading = false
                clearData()
                
                print("✅ Link de reset enviado por email")
                return true
            }
            
            // Si hay sesión activa, actualizar contraseña directamente
            try await currentUser.updatePassword(to: newPassword)
            
            isLoading = false
            clearData()
            
            print("✅ Contraseña actualizada exitosamente")
            return true
            
        } catch let error as NSError {
            // Si el token expiró, requerir re-autenticación
            if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                errorMessage = "Please log in again to change your password"
            } else {
                errorMessage = "Error resetting password: \(error.localizedDescription)"
            }
            showError = true
            isLoading = false
            return false
        }
    }
    
    // MARK: - Helper: Generar OTP
    private func generateOTP() -> String {
        let otp = Int.random(in: 100000...999999)
        return String(otp)
    }
    
    // MARK: - Helper: Guardar OTP en Firestore
    private func saveOTPToFirestore(email: String, code: String) async throws {
        let otpData: [String: Any] = [
            "email": email,
            "code": code,
            "createdAt": Timestamp(date: Date()),
            "expiresAt": Timestamp(date: Date().addingTimeInterval(300)), // 5 minutos
            "sent": false // La Cloud Function cambiará esto a true
        ]
        
        try await firestore
            .collection("password_resets")
            .document(email)
            .setData(otpData)
        
        print("📧 OTP guardado en Firestore - Cloud Function enviará el email")
    }
    
    // MARK: - Helper: Limpiar Datos
    private func clearData() {
        email = ""
        otpCode = ""
        newPassword = ""
        confirmPassword = ""
        generatedOTP = ""
        otpEmail = ""
    }
}

/*
 CONFIGURACIÓN PARA ENVIAR EMAILS REALES:
 
 ═══════════════════════════════════════════════════════════════════
 OPCIÓN 1: Firebase Extensions (MÁS FÁCIL - RECOMENDADO)
 ═══════════════════════════════════════════════════════════════════
 
 1. Ve a Firebase Console > Extensions
 2. Busca "Trigger Email from Firestore"
 3. Instala la extensión
 4. Configura:
    - SMTP Connection: Gmail, SendGrid, Mailgun, etc.
    - Collection path: password_resets
    - Email field: email
    - Template:
      Subject: Your Password Reset Code
      Body: Your verification code is: {{code}}
 
 5. La extensión enviará automáticamente emails cuando se cree un documento
 
 ═══════════════════════════════════════════════════════════════════
 OPCIÓN 2: Cloud Functions (MÁS CONTROL)
 ═══════════════════════════════════════════════════════════════════
 
 1. Instala Firebase CLI:
    npm install -g firebase-tools
 
 2. Inicializa Functions:
    firebase init functions
 
 3. Instala nodemailer:
    cd functions
    npm install nodemailer
 
 4. Crea esta función en functions/index.js:
 
 const functions = require('firebase-functions');
 const nodemailer = require('nodemailer');
 const admin = require('firebase-admin');
 admin.initializeApp();
 
 // Configurar transporter (ejemplo con Gmail)
 const transporter = nodemailer.createTransport({
   service: 'gmail',
   auth: {
     user: 'tu-email@gmail.com',
     pass: 'tu-app-password' // Genera esto en Google Account
   }
 });
 
 // Función que se activa cuando se crea un documento
 exports.sendOTPEmail = functions.firestore
   .document('password_resets/{email}')
   .onCreate(async (snap, context) => {
     const data = snap.data();
     const email = data.email;
     const code = data.code;
     
     const mailOptions = {
       from: 'JamSlip <noreply@jamslip.com>',
       to: email,
       subject: '🔐 Password Reset Code - JamSlip',
       html: `
         <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
           <h2 style="color: #333;">Password Reset</h2>
           <p>You requested to reset your password. Use the verification code below:</p>
           <div style="background: #f0f0f0; padding: 20px; text-align: center; margin: 20px 0;">
             <h1 style="color: #4285f4; font-size: 48px; margin: 0; letter-spacing: 8px;">${code}</h1>
           </div>
           <p style="color: #666;">This code will expire in 5 minutes.</p>
           <p style="color: #999; font-size: 12px;">If you didn't request this, please ignore this email.</p>
         </div>
       `
     };
     
     try {
       await transporter.sendMail(mailOptions);
       console.log('✅ Email sent to:', email);
       
       // Marcar como enviado
       await snap.ref.update({ sent: true });
     } catch (error) {
       console.error('❌ Error sending email:', error);
     }
   });
 
 5. Deploy:
    firebase deploy --only functions
 
 ═══════════════════════════════════════════════════════════════════
 OPCIÓN 3: Servicios de Email (MÁS PROFESIONAL)
 ═══════════════════════════════════════════════════════════════════
 
 Usa servicios como:
 - SendGrid (https://sendgrid.com) - 100 emails/día gratis
 - Mailgun (https://www.mailgun.com) - 5000 emails/mes gratis
 - Amazon SES (https://aws.amazon.com/ses/) - Muy económico
 
 Implementación similar a Cloud Functions pero usando sus APIs
 
 ═══════════════════════════════════════════════════════════════════
*/
