package com.cloudshop.product;
import jakarta.persistence.*; import jakarta.validation.constraints.*; import java.math.BigDecimal;
@Entity @Table(name="products") public class Product {
@Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
@NotBlank @Column(nullable=false) private String name;
@NotBlank @Column(nullable=false,length=1000) private String description;
@NotNull @DecimalMin("0.00") @Column(nullable=false,precision=12,scale=2) private BigDecimal price;
@Column(nullable=false) private String category;
public Product(){} public Product(String n,String d,BigDecimal p,String c){name=n;description=d;price=p;category=c;}
public Long getId(){return id;} public void setId(Long v){id=v;} public String getName(){return name;} public void setName(String v){name=v;}
public String getDescription(){return description;} public void setDescription(String v){description=v;} public BigDecimal getPrice(){return price;} public void setPrice(BigDecimal v){price=v;}
public String getCategory(){return category;} public void setCategory(String v){category=v;}}