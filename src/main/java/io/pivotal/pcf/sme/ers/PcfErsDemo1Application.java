package io.pivotal.pcf.sme.ers;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.security.servlet.SecurityAutoConfiguration;

/**
 * PcfErsDemo1Application
 * 
 * I just want to highlight the RibbonClient configuration (used by feign
 * clients). We would typically use Eureka (service registry), but for
 * simplicity we decided to support external configuration (in addition to the properties files).
 * 
 * @TODO: - Git versioning (maven plugin) - concourse CI/CD -
 * 
 * @author mborges
 *
 */
@SpringBootApplication(exclude = SecurityAutoConfiguration.class)
public class PcfErsDemo1Application {

	public static void main(String[] args) {
		SpringApplication.run(PcfErsDemo1Application.class, args);
	}
}
