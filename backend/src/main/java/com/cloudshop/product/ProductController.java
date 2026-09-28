package com.cloudshop.product;
import jakarta.validation.Valid; import org.springframework.http.HttpStatus; import org.springframework.web.bind.annotation.*; import java.util.List;
@RestController @RequestMapping("/api/products") public class ProductController {
private final ProductRepository repo; public ProductController(ProductRepository repo){this.repo=repo;}
@GetMapping public List<Product> all(){return repo.findAll();}
@GetMapping("/{id}") public Product one(@PathVariable Long id){return repo.findById(id).orElseThrow(()->new RuntimeException("Product not found: "+id));}
@PostMapping @ResponseStatus(HttpStatus.CREATED) public Product create(@Valid @RequestBody Product p){p.setId(null);return repo.save(p);}
@DeleteMapping("/{id}") @ResponseStatus(HttpStatus.NO_CONTENT) public void delete(@PathVariable Long id){repo.deleteById(id);}}