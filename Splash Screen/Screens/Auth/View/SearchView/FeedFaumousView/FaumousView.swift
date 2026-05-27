//
//  FaumousView.swift
//  Splash Screen
//
//  Created by Alexis Horteales Espinosa on 28/01/26.
//

import SwiftUI


struct FaumousView: View {
    
    @State var selected = "100 of Week"
    var body: some View {
        VStack{
            HStack{
                
                Text("So hotest")
                    .fontWeight(.bold)
                    .font(.system(size: 27))
                    .foregroundStyle(.black)
                Spacer()
                
                
                
            }
            .padding()
            
            ScrollView(.horizontal, showsIndicators: false){
                HStack(spacing: 25){
                    ForEach(menu, id: \.self){ item in
                        Button{
                            selected = item
                        }label: {
                            VStack{
                                Text(item)
                                    .fontWeight(.semibold)
                                    .font(.system(size: 15))
                                    .foregroundStyle(selected == item ? .black : .gray)
                                    .frame(width:estimateWidth(of: item, font: .systemFont(ofSize: 15)))
                                
                                
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(.black)
                                    .opacity(selected == item ? 1 : 0)
                                    .frame(width:estimateWidth(of: item, font: .systemFont(ofSize: 15)))
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            
            ScrollView(.horizontal, showsIndicators: false){
                HStack(spacing: 25){
                    ForEach(1...6, id: \.self){ _ in
                        GeometryReader{ proxy in
                            let minX = proxy.frame(in: .global).minX
                            let offset = 1 - (minX - 16) / 251 * 0.1
                            let cal = offset > 1 ? 1 - (offset - 1) : offset
                            
                            CoverView()
                                .scaleEffect(cal)
                                .offset(y: -(1 - cal) * 340 / 2)
                            
                        }
                        .frame(width: 210, height: 340)
                        
                    }
                }.padding(.horizontal)
            }
            
            HStack{
                Text("Trending")
                    .fontWeight(.bold)
                    .font(.system(size: 27))
                    .foregroundStyle(.black)
                Spacer()
            }
            .padding()
            
            ScrollView(.horizontal, showsIndicators: false){
                HStack(spacing: 0) {
                    TrendingView()
                }
            }
            
            
            Spacer()
        }
    }
    private func estimateWidth(of input: String, font: UIFont) -> CGFloat {
        return input.width(widthHeight: 25, font: font) + 5
    }

}

struct TrendingView: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(._12)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 141)
            
            VStack(alignment: .leading, spacing: 5){
                //song name
                Text("I love you")
                    .fontWeight(.bold)
                    .font(.system(size: 16))
                
                Spacer()
                
                Button{
                    
                }label: {
                    Image(systemName: "suit.heart")
                }
                .foregroundStyle(.black)
                
                //genre
                Text("Pop")
                    .font(.system(size: 12))
                    .fontWeight(.light)
                
                HStack{
                    Image(systemName: "suit.heart")
                    Text("32k")
                }
                HStack{
                    Image(systemName: "saved")
                    Text("10k")
                }
                HStack{
                    Image(systemName: "repost")
                    Text("12k")
                }
                .padding(.top, 5)
                
            }
        }
        .padding()
        .background(.white)
        .cornerRadius(15)
        .padding(.leading)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 0)
        .padding(.vertical, 5)
    }
}

struct CoverView: View {
    var body: some View {
        ZStack{
            Image(._10)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 149, height: 191)
                .shadow(color: Color.black.opacity(0.5), radius: 10, x: 25, y: 5)
            
            VStack{
                HStack{
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Pop")
                            .font(.system(size: 10))
                            .fontWeight(.light)
                        
                        Text("Falling in love")
                            .fontWeight(.bold)
                            .font(.system(size: 22))
                    }
                    Spacer()
//                    
//                    //here we cant give like
//                    Image(systemName: "suit.heart")
                }
                .foregroundStyle(.white)
                Spacer()
                
                HStack{
                    RoundedRectangle(cornerRadius: 5)
                        .frame(width: 20, height: 20)
                        Image(systemName: "suit.heart")
                    
                    RoundedRectangle(cornerRadius: 5)
                        .frame(width: 20, height: 20)
                        Image(systemName: "save")
                    
                    RoundedRectangle(cornerRadius: 5)
                        .frame(width: 20, height: 20)
                        Image(systemName: "repost")

                }
                Spacer()
                Text("Symbol and botton play")
                    .font(.system(size: 12))
                    
            }
        }
        .padding(12)

        .background(Color.secondary)
        .cornerRadius(15)
    }
}

#Preview{
    FaumousView()
}




///calculate width bas on content

extension String {
    func width(widthHeight height: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: .greatestFiniteMagnitude, height: height)
        let boundingRect = self.boundingRect(
            with: constraintRect,
            options: .usesLineFragmentOrigin,
            attributes: [.font: font],
            context: nil
        )
        return ceil(boundingRect.width)
    }
}



let menu = ["100 of Week", "100 More liked", "100 More Reposted"]
